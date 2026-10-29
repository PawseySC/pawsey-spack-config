#!/bin/bash
#
# Rebuild Singularity modulefiles, NOT Singularity itself.
#
# This driver connects machinery we already maintain:
#   1. Spack renders this checkout's systems/setonix/templates into a private
#      module tree, using metadata from an ALREADY INSTALLED SingularityCE spec.
#   2. create_custom_singularity_modules_from_general_singularity_container_engine.sh
#      turns that rendered module into the familiar -mpi, -nompi, etc. variants.
#
# The software prefix and its admin-granted privileges are never modified.
# By default, even the installed Spack template and live modulefiles are read-only
# inputs. Every run gets a new directory under MYSCRATCH for candidates and reports.
# Uncommitted template edits are deliberately included.
#
# --apply-live is the only way to publish candidates. Before replacing anything,
# we make hidden, timestamped backups alongside ALL affected live modulefiles.
# A saved manifest supports --restore; a failed deployment attempts rollback.
# Individual replacements are atomic, but the complete set is not one filesystem
# transaction. A killed process or machine failure may require explicit restore.
# Do not run this script with sudo.

set -eE -o pipefail

# =============================================================================
# 1. Read the command line: staging is the default, live writes are opt-in
# =============================================================================
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'USAGE'
Usage: update_singularity_modules.sh [OPTIONS]

  --date-tag TAG       Existing stack release; default: DATE_TAG or PAWSEY_STACK_VERSION.
  --version VERSION    One installed SingularityCE version; default: settings.sh.
  --stack-prefix DIR   Existing stack; default: /software/setonix/<date-tag>.
  --prefix DIR         Staging parent below MYSCRATCH; each run gets a new directory.
                       Default: $MYSCRATCH/singularity-module-updates/<date-tag>.
  --apply-live         Publish validated candidates, with hidden timestamped backups.
  --restore RUN_DIR    Restore a previous deployment; also requires --apply-live.
                       Use the same --date-tag and --stack-prefix as that deployment.
  -h, --help           Show this help.

Examples:
  bash scripts/update_singularity_modules.sh --date-tag 2026.09 --version 4.3.5
  bash scripts/update_singularity_modules.sh --date-tag 2026.09 --apply-live
  bash scripts/update_singularity_modules.sh --date-tag 2026.09 \
    --apply-live --restore /scratch/.../singularity-module-updates/2026.09/<run-id>

Nothing is installed, concretized, fetched, or rebuilt. Only the selected version
for settings.sh's cpu_arch and GCC is refreshed. Other versions remain untouched.
Live deployment updates its Spack source module and Pawsey variants, not templates
or shared Lmod helper scripts. Existing live helpers are required for deployment.
USAGE
}

date_tag=${DATE_TAG:-${PAWSEY_STACK_VERSION:-}}
version=""
stack_prefix=""
prefix=""
apply_live=0
restore=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --date-tag|--version|--stack-prefix|--prefix|--restore)
            [[ "$#" -ge 2 && -n "$2" ]] || die "Missing value for $1"
            case "$1" in
                --date-tag) date_tag=$2 ;;
                --version) version=$2 ;;
                --stack-prefix) stack_prefix=$2 ;;
                --prefix) prefix=$2 ;;
                --restore) restore=$2 ;;
            esac
            shift 2 ;;
        --apply-live) apply_live=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)" ;;
    esac
done

# =============================================================================
# 2. Identify the existing stack and read this checkout's official settings
# =============================================================================
[ "$(id -u)" -ne 0 ] || die "Do not run this script as root."
[[ "$date_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Supply a valid --date-tag."
[ -z "$restore" ] || [ "$apply_live" -eq 1 ] || die "--restore requires --apply-live."
PAWSEY_SPACK_CONFIG_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stack_prefix=$(realpath -e "${stack_prefix:-/software/setonix/$date_tag}")
[[ "${stack_prefix##*/}" == "$date_tag" ]] || die "The stack prefix must end in /$date_tag."
# The existing generator uses unquoted expansions; reject paths it cannot handle.
[[ "$stack_prefix" =~ ^/[A-Za-z0-9_./-]+$ ]] || die "Unsupported characters in stack prefix."

export SYSTEM=setonix DATE_TAG="$date_tag" INSTALL_PREFIX="$stack_prefix"
export INSTALL_GROUP="${INSTALL_GROUP:-$(id -gn)}"
unset __PSC_SETTINGS__
# Export the include guard too: the child generator must keep our staged paths.
set -a
# shellcheck source=/dev/null
. "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/settings.sh"
set +a
version=${version:-${singularity_mpi_version%-mpi}}
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "Supply a numeric SingularityCE --version."
: "${cpu_arch:?Missing cpu_arch in settings.sh}" "${gcc_version:?Missing gcc_version in settings.sh}"
: "${singularity_name_general:?Missing singularity_name_general in settings.sh}"
: "${singularity_name:?Missing singularity_name in settings.sh}"
: "${singularity_symlink_module_dir:?Missing singularity_symlink_module_dir in settings.sh}"
: "${python_name:?Missing python_name in settings.sh}" "${python_version:?Missing python_version in settings.sh}"
source_relative="modules/$cpu_arch/gcc/$gcc_version/utilities/$singularity_name_general"
variants_relative="$singularity_symlink_module_dir"

# =============================================================================
# 3. Small deployment helpers: back up first, replace atomically, restore safely
# =============================================================================
# A temporary file beside the target lets rename publish a complete file at once.
replacement=""
atomic_copy() {
    local from=$1 to=$2 preserve_target=${3:-0}
    replacement=$(mktemp "$(dirname "$to")/.singularity-update.XXXXXXXX") || return 1
    cp -p -- "$from" "$replacement" || return 1
    if [ "$preserve_target" -eq 1 ] && [ -f "$to" ]; then
        # A template edit must not change the existing module's access policy.
        chmod --reference="$to" "$replacement" || return 1
        chgrp --reference="$to" "$replacement" || return 1
    fi
    mv -fT -- "$replacement" "$to" || return 1
    replacement=""
}

lock_live_directories() {
    local directory
    # Refuse redirected target directories; never follow a modulefile symlink.
    for directory in "$stack_prefix/$source_relative" "$stack_prefix/$variants_relative"; do
        [[ -d "$directory" && "$(realpath -e "$directory")" = "$directory" ]] ||
            die "Live module directory is missing or redirected: $directory"
        [ -w "$directory" ] || die "Live module directory is not writable: $directory"
    done
    exec 8>"$stack_prefix/$source_relative/.singularity-module-update.lock"
    flock -n 8 || die "Another updater holds the Spack module directory lock."
    exec 9>"$stack_prefix/$variants_relative/.singularity-module-update.lock"
    flock -n 9 || die "Another updater holds the Pawsey module directory lock."
}

rollback() {
    local target backup old_hash new_hash failed=0
    while IFS=$'\t' read -r target backup old_hash new_hash; do
        if [ "$old_hash" = absent ]; then
            rm -f -- "$target" || failed=1
        else
            if ! atomic_copy "$backup" "$target"; then
                if [ -n "$replacement" ]; then rm -f -- "$replacement" || failed=1; fi
                replacement=""
                failed=1
            fi
        fi
    done < "$run/deployment.tsv"
    if [ "$failed" -ne 0 ]; then
        printf 'ERROR: Rollback incomplete. Keep backups and inspect %s/deployment.tsv\n' "$run" >&2
        return 1
    fi
    printf 'restored\n' > "$run/deployment-state"
}

deploying=0
on_exit() {
    local status=$?
    trap - EXIT
    # Clear a failed publication's temporary file before rollback reuses this
    # variable for its own atomic replacements.
    if [ -n "$replacement" ]; then rm -f -- "$replacement"; replacement=""; fi
    if [ "$deploying" -eq 1 ]; then
        printf 'Deployment interrupted; restoring the saved files.\n' >&2
        if ! rollback; then status=1; fi
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Restore is deliberately independent of Spack: it must work even if rendering is
# broken. Check EVERY backup and current checksum before changing the first file.
if [ -n "$restore" ]; then
    [ -z "$prefix" ] || die "--prefix cannot be combined with --restore."
    run=$(realpath -e "$restore")
    [[ -f "$run/stack-prefix" && "$(cat "$run/stack-prefix")" = "$stack_prefix" ]] ||
        die "This run does not belong to the selected stack."
    # Settings may have changed since deployment. Restore the recorded tree,
    # not whatever architecture/compiler happens to be configured today.
    [[ -f "$run/source-relative" && -f "$run/variants-relative" ]] ||
        die "Missing deployment directory metadata."
    source_relative=$(cat "$run/source-relative")
    variants_relative=$(cat "$run/variants-relative")
    [[ "$source_relative" =~ ^modules/[A-Za-z0-9_-]+/gcc/[0-9.]+/utilities/singularityce$ &&
       "$variants_relative" = pawsey/modules/singularity ]] ||
        die "Unexpected deployment directory metadata."
    [[ -f "$run/deployment-state" && "$(cat "$run/deployment-state")" != restored ]] ||
        die "This run has no deployment to restore (or was already restored)."
    [ -s "$run/deployment.tsv" ] || die "Missing deployment manifest."
    lock_live_directories
    while IFS=$'\t' read -r target backup old_hash new_hash; do
        # Limit restore targets to this driver's two module directories.
        case "${target%/*}" in
            "$stack_prefix/$source_relative"|"$stack_prefix/$variants_relative") ;;
            *) die "Unexpected restore target: $target" ;;
        esac
        [[ "${target##*/}" =~ ^[0-9]+(\.[0-9]+)*(-[a-z-]+)?\.lua$ ]] ||
            die "Unexpected module filename in manifest: $target"
        [ ! -L "$target" ] || die "Refusing to restore over a symlink: $target"
        # A hard interruption may leave some originals and some new files.
        current_hash=absent
        if [ -f "$target" ]; then current_hash=$(sha256sum "$target" | cut -d ' ' -f1); fi
        [[ "$current_hash" = "$new_hash" || "$current_hash" = "$old_hash" ]] ||
            die "Module changed since deployment; refusing to overwrite it: $target"
        if [ "$old_hash" != absent ]; then
            [ "$backup" = "$(dirname "$target")/.${target##*/}.${run##*/}.bak" ] ||
                die "Unexpected backup filename: $backup"
            [[ -f "$backup" && ! -L "$backup" &&
                "$(sha256sum "$backup" | cut -d ' ' -f1)" = "$old_hash" ]] ||
                die "Missing or changed backup: $backup"
        fi
    done < "$run/deployment.tsv"
    rollback
    printf 'Restored deployment from %s; hidden backups have been retained.\n' "$run"
    exit 0
fi

# =============================================================================
# 4. Create a fresh, private run directory; never reuse the live output tree
# =============================================================================
[[ -n "${MYSCRATCH:-}" && -d "$MYSCRATCH" ]] || die "MYSCRATCH must be an existing directory."
scratch=$(realpath -e "$MYSCRATCH")
prefix=$(realpath -m "${prefix:-$scratch/singularity-module-updates/$date_tag}")
[[ "$prefix" =~ ^/[A-Za-z0-9_./-]+$ ]] || die "Unsupported characters in staging prefix."
[[ "$prefix" == "$scratch/"* && "$prefix" != "$scratch" ]] ||
    die "The staging prefix must be strictly below MYSCRATCH."
[[ "$prefix/" != "$stack_prefix/"* && "$prefix/" != "$PAWSEY_SPACK_CONFIG_REPO/"* ]] ||
    die "Keep staging outside the live stack and repository."
mkdir -p "$prefix"
[ -O "$prefix" ] || die "The staging parent must belong to you."
run=$(mktemp -d "$prefix/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
stage="$run/tree"
mkdir -p "$stage" "$run/templates" "$run/site" "$run/staff" "$run/overrides" "$run/cache"
printf '%s\n' "$stack_prefix" > "$run/stack-prefix"
printf '%s\n' "$source_relative" > "$run/source-relative"
printf '%s\n' "$variants_relative" > "$run/variants-relative"
printf 'Run directory: %s\nExisting stack: %s\nSingularityCE: %s\n' "$run" "$stack_prefix" "$version"

# Save the actual inputs, including uncommitted edits, for later diagnosis.
git -C "$PAWSEY_SPACK_CONFIG_REPO" rev-parse HEAD > "$run/repository-commit"
git -C "$PAWSEY_SPACK_CONFIG_REPO" status --short --branch > "$run/repository-status"
cp -R "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/." "$run/templates/"
generator="$PAWSEY_SPACK_CONFIG_REPO/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"
sha256sum "$generator" "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/modules/modulefile.lua" \
    > "$run/input-checksums"

# =============================================================================
# 5. Give Spack temporary configuration, not a new software installation
# =============================================================================
# Use the real executable: Pawsey's wrapper does not preserve quoted arguments.
spack="$stack_prefix/spack/bin/realspack"
[ -x "$spack" ] || die "Installed Spack executable not found: $spack"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/site/modules.yaml" "$run/site/"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/spackuser/modules.yaml" "$run/staff/"

# Match install_spack.sh's placeholder substitutions, but only in private copies.
# INSTALL_PREFIX remains the REAL stack: package and helper paths must stay real.
sed -i \
    -e "s|INSTALL_PREFIX|$stack_prefix|g" \
    -e "s|DATE_TAG|$date_tag|g" \
    -e "s|USER_PERMANENT_FILES_PREFIX|$USER_PERMANENT_FILES_PREFIX|g" \
    -e "s|USER_TEMP_FILES_PREFIX|$USER_TEMP_FILES_PREFIX|g" \
    -e "s|BOOTSTRAP_PATH|$BOOTSTRAP_PATH|g" \
    "$run/templates/modules/modulefile.lua" "$run/site/modules.yaml" "$run/staff/modules.yaml"

# Configuration precedence: installed site, checkout site, checkout staff, then
# these final safety overrides. Double colons REPLACE lists/mappings in Spack.
cat > "$run/overrides/config.yaml" <<EOF
config:
  install_tree:
    root: '$stack_prefix/software'
  template_dirs::
    - '$run/templates'
  misc_cache: '$run/cache/misc'
  source_cache: '$run/cache/sources'
EOF
cat > "$run/overrides/modules.yaml" <<EOF
modules:
  default:
    roots:
      lmod: '$stage/modules'
EOF
printf 'upstreams:: {}\n' > "$run/overrides/upstreams.yaml"
printf 'bootstrap:\n  enable: false\n' > "$run/overrides/bootstrap.yaml"

# Reuse ONLY existing recipe repositories; no registry fetch or user-repo init.
# This is the layout installed by this repository for Spack 1.1.1.
builtin="$stack_prefix/spack/var/spack/repos/builtin/repos/spack_repo/builtin"
pawsey="$stack_prefix/spack/var/spack/repos/pawsey"
[[ -f "$builtin/repo.yaml" && -f "$pawsey/repo.yaml" ]] ||
    die "Expected installed Spack 1.1.1 recipe repositories are missing."
cat > "$run/overrides/repos.yaml" <<EOF
repos::
  pawsey_repo: '$pawsey'
  builtin: '$builtin'
EOF
export SPACK_DISABLE_LOCAL_CONFIG=1
export SPACK_USER_CONFIG_PATH="$run/user-config" SPACK_USER_CACHE_PATH="$run/cache/user"
export SPACK_SYSTEM_CONFIG_PATH="$run/system-config"
# Importing recipes must not create bytecode files in the installed Spack tree.
export PYTHONDONTWRITEBYTECODE=1
# Spack's Python command otherwise executes a personal startup file as well.
unset PYTHONSTARTUP
spack_command=("$spack" -E -C "$run/site" -C "$run/staff" -C "$run/overrides")

# Like the installed Spack module, use the stack's Python, not the OS Python.
# Old system interpreters may start Spack but cannot import installed recipes.
type module >/dev/null 2>&1 || die "The Lmod module command must be available."
module use "$stack_prefix/modules/$cpu_arch/gcc/$gcc_version/programming-languages"
module load "$python_name/$python_version"
export SPACK_PYTHON
SPACK_PYTHON=$(command -v python3) || die "The stack's Python module did not expose python3."

# =============================================================================
# 6. Find ONE installed spec and ask Spack to render its source module
# =============================================================================
# Compiler constraint parsing can initialize compiler recipes. Query by package
# and target, then compare the compiler metadata from the installed records.
"${spack_command[@]}" find --format '{hash} {prefix} {compiler.name} {compiler.version}' \
    "$singularity_name_general@=$version target=$cpu_arch" > "$run/installed-specs.txt"
matches=()
while read -r hash installed_prefix compiler compiler_version; do
    if [ "$compiler" = gcc ] && [ "$compiler_version" = "$gcc_version" ]; then
        matches+=("$hash")
        package_prefix=$installed_prefix
    fi
done < "$run/installed-specs.txt"
[ "${#matches[@]}" -eq 1 ] ||
    die "Expected one installed $singularity_name_general@$version for $cpu_arch/GCC $gcc_version; found ${#matches[@]}. See $run/installed-specs.txt"
[[ "$package_prefix" == "$stack_prefix/software/"* && -d "$package_prefix" ]] ||
    die "Selected package is not installed inside this stack."
hash=${matches[0]}
[[ "$hash" =~ ^[a-z0-9]+$ ]] || die "Unexpected installed spec hash: $hash"
printf '%s\n' "$hash" > "$run/spec-hash"
printf 'Reusing installed package: %s\n' "$package_prefix"

# Check Spack's layout BEFORE asking it to write anything. Unlike `module find`,
# this API can calculate the filename before a module actually exists.
source_module="$stage/$source_relative/$version.lua"
resolved=$("${spack_command[@]}" python -c \
    "import spack.store, spack.modules.lmod; spec = spack.store.STORE.db.query('/$hash')[0]; print(spack.modules.lmod.LmodModulefileWriter(spec, 'default').layout.filename)")
[ "$resolved" = "$source_module" ] ||
    die "Spack resolved an unexpected output path: $resolved (expected $source_module)"
"${spack_command[@]}" module lmod refresh -y "/$hash" 2>&1 | tee "$run/spack-refresh.log"
# Spack can warn about a rendering error but still exit zero; verify its product.
[ -s "$source_module" ] || die "Spack did not produce the expected source module."
if grep -Eq '\{\{|\{%' "$source_module"; then die "Source module contains unrendered template expressions."; fi
grep -Fq "$package_prefix/bin" "$source_module" || die "Source module does not reference the installed binary."

# =============================================================================
# 7. Call the EXISTING variant generator, confined to this fresh staging tree
# =============================================================================
# Its include guard preserves the staged INSTALL_PREFIX instead of re-sourcing
# settings.sh. It can freely clean its destination here: there are no live files.
(
    export INSTALL_PREFIX="$stage"
    bash -e "$generator"
) 2>&1 | tee "$run/variant-generation.log"
variant_directory="$stage/$variants_relative"
shopt -s nullglob
candidates=("$source_module" "$variant_directory/$version-"*.lua)
[ "${#candidates[@]}" -gt 1 ] || die "The repository generator produced no variants."

# =============================================================================
# 8. Validate and report candidates before any possible live deployment
# =============================================================================
command -v luac >/dev/null || die "luac is required to syntax-check generated Lua."
type module >/dev/null 2>&1 || die "The Lmod module command must be available."
for candidate in "${candidates[@]}"; do
    [ -s "$candidate" ] || die "Empty generated module: $candidate"
    luac -p "$candidate"
    if [[ "$candidate" == "$variant_directory/"* ]]; then
        name="$singularity_name/${candidate##*/}"
        name=${name%.lua}
        (
            # An inherited live module with the same name can otherwise mask
            # the candidate. Unloading here affects only this validation shell.
            module unload "$singularity_name"
            module use "$stage/${variants_relative%/"$singularity_name"}"
            # Bypass the module cache and prove we are testing the staged file.
            location=$(module --ignore-cache --redirect --location show "$name")
            [ "$location" = "$candidate" ] || die "Lmod selected a non-staged module: $location"
            module --ignore-cache --redirect show "$name"
        ) > "$run/${candidate##*/}.show.log" 2>&1 ||
            die "Lmod validation failed; see $run/${candidate##*/}.show.log"
    fi
done

# A diff is a report, not a failure: status 1 means the candidate is different.
: > "$run/changes.diff"
for candidate in "${candidates[@]}"; do
    target="$stack_prefix/${candidate#"$stage/"}"
    if [ -e "$target" ]; then
        status=0
        diff -u "$target" "$candidate" >> "$run/changes.diff" || status=$?
        [ "$status" -le 1 ] || die "Could not compare $target"
    else
        printf '\nNEW MODULE: %s\n' "$target" >> "$run/changes.diff"
    fi
done
printf '\nValidated %s modulefiles. Diff: %s/changes.diff\n' "${#candidates[@]}" "$run"
printf 'Test with: module unload %q\n' "$singularity_name"
printf '           module use %q\n' "$stage/${variants_relative%/"$singularity_name"}"
printf '           module load %s/%s-mpi\n' "$singularity_name" "$version"
if [ "$apply_live" -eq 0 ]; then
    printf 'Staging only: no live modulefiles, templates, or software were changed.\n'
    exit 0
fi

# =============================================================================
# 9. Explicit live deployment: prepare ALL backups before the first replacement
# =============================================================================
lock_live_directories
# Staged modules retain real helper paths. Do not silently deploy helper changes.
for helper in pawsey_fix_initial_bash.lua pawsey_init_bash; do
    [ -r "$stack_prefix/pawsey/lmod-variable-fixes/$helper" ] ||
        die "Required live Lmod helper is missing: $helper"
done
printf '\nPublishing ONLY these files (all other versions stay untouched):\n'
: > "$run/deployment.tsv"
for candidate in "${candidates[@]}"; do
    target="$stack_prefix/${candidate#"$stage/"}"
    backup="$(dirname "$target")/.${target##*/}.${run##*/}.bak"
    [ ! -L "$target" ] || die "Refusing to replace a symlink: $target"
    [[ ! -e "$backup" && ! -L "$backup" ]] || die "Backup already exists: $backup"
    old_hash=absent
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "Live module is not a regular file: $target"
        cp -p -- "$target" "$backup"
        old_hash=$(sha256sum "$target" | cut -d ' ' -f1)
        [ "$(sha256sum "$backup" | cut -d ' ' -f1)" = "$old_hash" ] ||
            die "Backup checksum mismatch: $backup"
    fi
    new_hash=$(sha256sum "$candidate" | cut -d ' ' -f1)
    printf '%s\t%s\t%s\t%s\n' "$target" "$backup" "$old_hash" "$new_hash" >> "$run/deployment.tsv"
    printf '  %s\n' "$target"
done
printf 'deploying\n' > "$run/deployment-state"
deploying=1
for candidate in "${candidates[@]}"; do
    atomic_copy "$candidate" "$stack_prefix/${candidate#"$stage/"}" 1
done
printf 'deployed\n' > "$run/deployment-state"
deploying=0
printf 'Deployment complete. Hidden backups retained; manifest: %s/deployment.tsv\n' "$run"
printf 'Restore with: bash %q --date-tag %q --stack-prefix %q --apply-live --restore %q\n' \
    "$PAWSEY_SPACK_CONFIG_REPO/scripts/update_singularity_modules.sh" "$date_tag" "$stack_prefix" "$run"
