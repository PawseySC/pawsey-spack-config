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
# --apply-live publishes candidates to live module directories. The
# --replace-in-test option exercises that same backup-and-replace path against a
# previous private staging run instead. Both modes back up affected modulefiles.
# A saved manifest supports --restore; a failed deployment attempts rollback.
# Individual replacements are atomic, but the complete set is not one filesystem
# transaction. A killed process or machine failure may require explicit restore.
# Do not run this script with sudo unless you fully understand the implications.
#
# NOTE: Initially developed by Alexis Espinosa with assistance from an AI
#       assistant using GitHub Copilot SDK in Visual Studio Code, with automatic
#       model selection and the Balanced setting.
#       The initial version was fully reviewed and tested by Alexis Espinosa.
set -eE -o pipefail

# =============================================================================
# 1. Read the command line: staging is the default, live writes are opt-in
# =============================================================================
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'USAGE'
Usage: update_singularity_modules.sh --version VERSION [OPTIONS]

  --date-tag TAG       Existing stack release; default: DATE_TAG or PAWSEY_STACK_VERSION.
  --version VERSION    Required installed SingularityCE version; no default.
  --suffix LABEL       Append -LABEL to generated module names, leaving unlabelled files untouched.
  --stack-prefix DIR   Existing stack; default: /software/setonix/<date-tag>.
  --prefix DIR         Staging parent below MYSCRATCH; each run gets a new directory.
                       Default: $MYSCRATCH/singularity-module-updates/<date-tag>.
  --replace-in-test RUN_DIR
                       Replace an earlier staging run under MYSCRATCH.
                       Keep hidden backups beside the replaced test modulefiles.
  --apply-live         Publish validated candidates, with hidden timestamped backups.
  --restore            Undo the latest matching replacement; repeat to go back further.
                       Requires --apply-live or --replace-in-test and the same --suffix.
  --repair             Recover the latest active deployment's exact saved files.
                       Preserve edited files beside the modules before replacement.
  --force              With --restore only: preserve and overwrite later manual edits.
  -h, --help           Show this help.

Examples:
  bash scripts/update_singularity_modules.sh --date-tag 2026.09 --version 4.3.5
  bash scripts/update_singularity_modules.sh --version 4.3.5 --date-tag 2026.09 --apply-live
  bash scripts/update_singularity_modules.sh --date-tag 2026.09 \
    --version 4.3.5 --apply-live --restore

Nothing is installed, concretized, fetched, or rebuilt. Only the selected version
for settings.sh's cpu_arch and GCC is refreshed. Other versions remain untouched.
Live deployment updates its Spack source module and Pawsey variants, not templates
or shared Lmod helper scripts. Existing live helpers are required for deployment.
USAGE
}

date_tag=${DATE_TAG:-${PAWSEY_STACK_VERSION:-}}
version=""
suffix=""
stack_prefix=""
prefix=""
apply_live=0
restore=""
repair=""
force=0
test_run=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --date-tag|--version|--suffix|--stack-prefix|--prefix|--replace-in-test)
            [[ "$#" -ge 2 && -n "$2" ]] || die "Missing value for $1"
            case "$1" in
                --date-tag) date_tag=$2 ;;
                --version) version=$2 ;;
                --suffix) suffix=$2 ;;
                --stack-prefix) stack_prefix=$2 ;;
                --prefix) prefix=$2 ;;
                --replace-in-test) test_run=$2 ;;
            esac
            shift 2 ;;
        --apply-live) apply_live=1; shift ;;
        --restore) restore=1; shift ;;
        --repair) repair=1; shift ;;
        --force) force=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)" ;;
    esac
done

[ -n "$version" ] || die "--version VERSION is required (use --help)."
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "Supply a numeric SingularityCE --version."
[ -z "$restore" ] || [ -z "$repair" ] || die "--restore and --repair cannot be combined."
[ "$force" -eq 0 ] || [ -n "$restore" ] || die "--force requires --restore."

# =============================================================================
# 2. Identify the existing stack and read this checkout's official settings
# =============================================================================
[ "$(id -u)" -ne 0 ] || die "Do not run this script as root."
[[ "$date_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Supply a valid --date-tag."
[ -z "$restore" ] || [ "$apply_live" -eq 1 ] || [ -n "$test_run" ] ||
    die "--restore requires --apply-live or --replace-in-test."
[ -z "$repair" ] || [ "$apply_live" -eq 1 ] || [ -n "$test_run" ] ||
    die "--repair requires --apply-live or --replace-in-test."
[ "$apply_live" -eq 0 ] || [ -z "$test_run" ] ||
    die "Choose either --apply-live or --replace-in-test, not both."
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
[[ -z "$suffix" || "$suffix" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] ||
    die "--suffix must start with a letter or digit and contain only letters, digits, underscores, or hyphens."
module_suffix=${suffix:+-$suffix}
: "${cpu_arch:?Missing cpu_arch in settings.sh}" "${gcc_version:?Missing gcc_version in settings.sh}"
: "${singularity_name_general:?Missing singularity_name_general in settings.sh}"
: "${singularity_name:?Missing singularity_name in settings.sh}"
: "${singularity_symlink_module_dir:?Missing singularity_symlink_module_dir in settings.sh}"
: "${python_name:?Missing python_name in settings.sh}" "${python_version:?Missing python_version in settings.sh}"
# shellcheck source=scripts/singularity_module_pipeline.sh
. "$PAWSEY_SPACK_CONFIG_REPO/scripts/singularity_module_pipeline.sh"
psc_singularity_module_paths

# A test replacement must target an earlier run created below this user's
# MYSCRATCH. The canonicalized run and module directories must not be symlinks.
test_tree=""
if [ -n "$test_run" ]; then
    [[ -n "${MYSCRATCH:-}" && -d "$MYSCRATCH" ]] || die "MYSCRATCH must be an existing directory."
    scratch=$(realpath -e "$MYSCRATCH")
    test_parent="$scratch/singularity-module-updates/$date_tag"
    test_run=$(realpath -e "$test_run")
    [[ "$test_run" == "$test_parent/"* && -d "$test_run/tree" ]] ||
        die "--replace-in-test must name an earlier run below $test_parent."
    [ -O "$test_run" ] || die "The test run directory must belong to you."
    test_tree="$test_run/tree"
    [[ "$(realpath -e "$test_tree")" = "$test_tree" ]] ||
        die "The test module tree must not be redirected through a symlink."
    [[ "$test_tree" =~ ^/[A-Za-z0-9_./-]+$ ]] || die "Unsupported characters in test tree path."
    for relative in "$source_relative" "$variants_relative"; do
        [[ -d "$test_tree/$relative" && "$(realpath -e "$test_tree/$relative")" = "$test_tree/$relative" ]] ||
            die "Test module directory is missing or redirected: $test_tree/$relative"
    done
fi

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

lock_target_directories() {
    local directory
    # Refuse redirected target directories; never follow a modulefile symlink.
    for directory in "$target_root/$source_relative" "$target_root/$variants_relative"; do
        [[ -d "$directory" && "$(realpath -e "$directory")" = "$directory" ]] ||
            die "Live module directory is missing or redirected: $directory"
        [ -w "$directory" ] || die "Live module directory is not writable: $directory"
    done
    exec 8>"$target_root/$source_relative/.singularity-module-update.lock"
    flock -n 8 || die "Another updater holds the Spack module directory lock."
    exec 9>"$target_root/$variants_relative/.singularity-module-update.lock"
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

collect_restore_history() {
    local directory manifest recorded_root recorded_mode state order entry
    local history_parent="${prefix:-${MYSCRATCH:?MYSCRATCH is required}/singularity-module-updates/$date_tag}"
    local -A directories=()
    local -a ordered=()
    # Include older deployments made before the destination history index existed.
    for manifest in "$history_parent"/*/deployment.tsv; do
        [ -f "$manifest" ] || continue
        directories["${manifest%/*}"]=0
    done
    if [ -f "$history_index" ]; then
        while IFS= read -r directory; do
            [ -n "$directory" ] || die "Empty deployment history entry: $history_index"
            [ -d "$directory" ] || die "Saved deployment history is missing: $directory"
            directories["$directory"]=1
        done < "$history_index"
    fi
    for directory in "${!directories[@]}"; do
        manifest="$directory/deployment.tsv"
        [[ -f "$directory/stack-prefix" &&
            "$(cat "$directory/stack-prefix")" = "$stack_prefix" ]] || continue
        recorded_mode=live
        [ ! -f "$directory/deployment-mode" ] ||
            recorded_mode=$(cat "$directory/deployment-mode")
        recorded_root=$stack_prefix
        [ ! -f "$directory/deployment-root" ] ||
            recorded_root=$(cat "$directory/deployment-root")
        [[ "$recorded_mode" = "$expected_mode" && "$recorded_root" = "$target_root" ]] || continue
        # A failed backup-preparation phase has not published any files.
        if [ ! -f "$directory/deployment-state" ]; then
            [ "${directories[$directory]}" -eq 0 ] && continue
            die "Missing deployment state: $directory"
        fi
        # The source filename identifies version and suffix even for legacy runs.
        [ -f "$manifest" ] || die "Missing deployment manifest: $manifest"
        IFS=$'\t' read -r entry _ < "$manifest" || die "Empty deployment manifest: $manifest"
        [ "$entry" = "$target_root/$source_relative/$version$module_suffix.lua" ] || continue
        state=$(cat "$directory/deployment-state")
        [ "$state" != restored ] || continue
        [[ "$state" = deploying || "$state" = deployed ]] ||
            die "Unexpected deployment state in $directory: $state"
        if [ -f "$directory/deployment-order" ]; then
            order=$(cat "$directory/deployment-order")
        else
            order="$(stat -c %Y "$manifest")000000000"
        fi
        [[ "$order" =~ ^[0-9]+$ ]] || die "Invalid deployment order: $directory"
        ordered+=("$order"$'\t'"$directory")
    done
    restore_history=()
    if [ "${#ordered[@]}" -gt 0 ]; then
        mapfile -t restore_history < <(printf '%s\n' "${ordered[@]}" | LC_ALL=C sort -rn)
    fi
}

# Restore is deliberately independent of Spack: it must work even if rendering is
# broken. Check EVERY backup and current checksum before changing the first file.
if [ -n "$restore$repair" ]; then
    expected_mode=live
    target_root=$stack_prefix
    if [ -n "$test_run" ]; then
        expected_mode="test"
        target_root=$test_tree
    fi
    lock_target_directories
    history_index="$target_root/$source_relative/.singularity-module-history"
    collect_restore_history
    [ "${#restore_history[@]}" -gt 0 ] ||
        die "No replacements remain in saved history for this destination, version, and suffix."
    run=${restore_history[0]#*$'\t'}
    if [ -n "$repair" ]; then
        printf 'Repairing latest active replacement: %s\n' "$run"
        [ "$(cat "$run/deployment-state")" = deployed ] ||
            die "Cannot repair an interrupted deployment; restore it first."
    else
        printf 'Undoing latest replacement: %s\n' "$run"
    fi
    if [ -f "$run/deployment-time" ]; then
        printf 'Replacement time (UTC): %s\n' "$(cat "$run/deployment-time")"
    else
        printf 'Legacy replacement run: %s\n' "${run##*/}"
    fi
    [[ -f "$run/stack-prefix" && "$(cat "$run/stack-prefix")" = "$stack_prefix" ]] ||
        die "This run does not belong to the selected stack."
    # Settings may have changed since deployment. Restore the recorded tree,
    # not whatever architecture/compiler happens to be configured today.
    [[ -f "$run/source-relative" && -f "$run/variants-relative" ]] ||
        die "Missing deployment directory metadata."
    expected_mode=live
    target_root=$stack_prefix
    if [ -n "$test_run" ]; then
        expected_mode="test"
        target_root=$test_tree
    fi
    recorded_mode=live
    [ ! -f "$run/deployment-mode" ] || recorded_mode=$(cat "$run/deployment-mode")
    [[ "$recorded_mode" = "$expected_mode" ]] ||
        die "Deployment mode mismatch: expected $expected_mode, found $recorded_mode."
    if [ -f "$run/deployment-root" ]; then
        [[ "$(cat "$run/deployment-root")" = "$target_root" ]] ||
            die "Restore target does not match the deployment target."
    elif [ "$expected_mode" = test ]; then
        die "This deployment has no test-target metadata."
    fi
    source_relative=$(cat "$run/source-relative")
    variants_relative=$(cat "$run/variants-relative")
    [[ "$source_relative" =~ ^modules/[A-Za-z0-9_-]+/gcc/[0-9.]+/utilities/singularityce$ &&
       "$variants_relative" = pawsey/modules/singularity ]] ||
        die "Unexpected deployment directory metadata."
    [[ -f "$run/deployment-state" && "$(cat "$run/deployment-state")" != restored ]] ||
        die "This run has no deployment to restore (or was already restored)."
    [ -s "$run/deployment.tsv" ] || die "Missing deployment manifest."
    changed_targets=()
    changed_hashes=()
    repair_candidates=()
    while IFS=$'\t' read -r target backup old_hash new_hash; do
        # Limit restore targets to this driver's two module directories.
        case "${target%/*}" in
            "$target_root/$source_relative"|"$target_root/$variants_relative") ;;
            *) die "Unexpected restore target: $target" ;;
        esac
        [[ "${target##*/}" =~ ^[0-9]+(\.[0-9]+)*(-[A-Za-z0-9][A-Za-z0-9_-]*)?\.lua$ ]] ||
            die "Unexpected module filename in manifest: $target"
        [ ! -L "$target" ] || die "Refusing to restore over a symlink: $target"
        [[ ! -e "$target" || -f "$target" ]] || die "Module is not a regular file: $target"
        # A hard interruption may leave some originals and some new files.
        current_hash=absent
        if [ -f "$target" ]; then current_hash=$(sha256sum "$target" | cut -d ' ' -f1); fi
        if [ -n "$repair" ]; then
            candidate="$run/tree/${target#"$target_root/"}"
            [[ -f "$candidate" && ! -L "$candidate" &&
                "$(sha256sum "$candidate" | cut -d ' ' -f1)" = "$new_hash" ]] ||
                die "Missing or changed saved candidate: $candidate"
            if [ "$current_hash" != "$new_hash" ]; then
                changed_targets+=("$target")
                changed_hashes+=("$current_hash")
                repair_candidates+=("$candidate")
            fi
        elif [[ "$current_hash" != "$new_hash" && "$current_hash" != "$old_hash" ]]; then
            [ "$force" -eq 1 ] ||
                die "Module changed since deployment; use --repair or --restore --force: $target"
            changed_targets+=("$target")
            changed_hashes+=("$current_hash")
        fi
        if [ -z "$repair" ] && [ "$old_hash" != absent ]; then
            [ "$backup" = "$(dirname "$target")/.${target##*/}.${run##*/}.bak" ] ||
                die "Unexpected backup filename: $backup"
            [[ -f "$backup" && ! -L "$backup" &&
                "$(sha256sum "$backup" | cut -d ' ' -f1)" = "$old_hash" ]] ||
                die "Missing or changed backup: $backup"
        fi
    done < "$run/deployment.tsv"
    # Validate every input first, then preserve every affected current file before
    # changing any module. A repair has its own rollback journal, not a deployment.
    if [ "${#changed_targets[@]}" -gt 0 ]; then
        operation=restore
        [ -z "$repair" ] || operation=repair
        recovery=$(mktemp -d "$run/before-$operation.$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
        : > "$recovery/deployment.tsv"
        for index in "${!changed_targets[@]}"; do
            target=${changed_targets[$index]}
            current_hash=${changed_hashes[$index]}
            backup="$(dirname "$target")/.${target##*/}.${recovery##*/}.bak"
            [[ ! -e "$backup" && ! -L "$backup" ]] || die "Preservation backup already exists: $backup"
            if [ "$current_hash" != absent ]; then
                cp -p -- "$target" "$backup"
                [ "$(sha256sum "$backup" | cut -d ' ' -f1)" = "$current_hash" ] ||
                    die "Preservation backup checksum mismatch: $backup"
                printf 'Preserved current file: %s\n' "$backup"
            else
                printf 'Module missing; no current file to preserve: %s\n' "$target"
            fi
            printf '%s\t%s\t%s\t%s\n' "$target" "$backup" "$current_hash" unused \
                >> "$recovery/deployment.tsv"
        done
    fi
    if [ -n "$repair" ]; then
        if [ "${#changed_targets[@]}" -eq 0 ]; then
            printf 'No repair needed: all modules match the saved deployment.\n'
        else
            deployment_run=$run
            run=$recovery
            deploying=1
            for index in "${!changed_targets[@]}"; do
                atomic_copy "${repair_candidates[$index]}" "${changed_targets[$index]}" 1
            done
            deploying=0
            printf 'repaired\n' > "$run/deployment-state"
            run=$deployment_run
            printf 'Repair complete. Deployment history unchanged; preserved files recorded in %s/deployment.tsv\n' "$recovery"
        fi
        exit 0
    fi
    rollback
    printf 'Restored deployment from %s; hidden backups have been retained.\n' "$run"
    remaining=$((${#restore_history[@]} - 1))
    if [ "$remaining" -gt 0 ]; then
        printf '%s earlier replacement(s) remain in saved history for this destination, version, and suffix.\n' "$remaining"
        printf 'Run the same restore command again to undo the next one; backups will be validated first.\n'
    else
        printf 'No earlier replacements remain in saved history for this destination, version, and suffix.\n'
    fi
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
printf '%s\n' "$suffix" > "$run/module-suffix"
printf 'Run directory: %s\nExisting stack: %s\nSingularityCE: %s\n' "$run" "$stack_prefix" "$version"

# Save the actual inputs, including uncommitted edits, for later diagnosis.
git -C "$PAWSEY_SPACK_CONFIG_REPO" rev-parse HEAD > "$run/repository-commit"
git -C "$PAWSEY_SPACK_CONFIG_REPO" status --short --branch > "$run/repository-status"
# =============================================================================
# 5. Run the same preparation, Spack rendering, and variants as installation
# =============================================================================
psc_generate_singularity_modules "$stack_prefix" "$stage" "$run" "$version"
source_module="$stage/$source_relative/$version.lua"
variant_directory="$stage/$variants_relative"
shopt -s nullglob
candidates=("$source_module" "$variant_directory/$version-"*.lua)
[ "${#candidates[@]}" -gt 1 ] || die "The repository generator produced no variants."
if [ -n "$suffix" ]; then
    for index in "${!candidates[@]}"; do
        candidate=${candidates[$index]}
        labelled="${candidate%.lua}$module_suffix.lua"
        mv -- "$candidate" "$labelled"
        candidates[$index]=$labelled
    done
    source_module=${candidates[0]}
fi

# =============================================================================
# 6. Validate and report candidates before any possible live deployment
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
comparison_root=${test_tree:-$stack_prefix}
for candidate in "${candidates[@]}"; do
    target="$comparison_root/${candidate#"$stage/"}"
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
printf '           module load %s/%s-mpi%s\n' "$singularity_name" "$version" "$module_suffix"
if [ "$apply_live" -eq 0 ] && [ -z "$test_run" ]; then
    printf 'Staging only: no live modulefiles, templates, or software were changed.\n'
    exit 0
fi

# =============================================================================
# 7. Explicit publication: choose the target, then prepare ALL backups first
# =============================================================================
deployment_mode=live
target_root=$stack_prefix
if [ -n "$test_run" ]; then
    deployment_mode="test"
    target_root=$test_tree
    printf '\nReplacing only files in test tree: %s\n' "$test_tree"
else
    printf '\nPublishing only to live module directories.\n'
fi
lock_target_directories
# Staged modules retain real helper paths. Do not silently deploy helper changes.
for helper in pawsey_fix_initial_bash.lua pawsey_init_bash; do
    [ -r "$stack_prefix/pawsey/lmod-variable-fixes/$helper" ] ||
        die "Required live Lmod helper is missing: $helper"
done
printf '\nPublishing ONLY these files (all other versions stay untouched):\n'
: > "$run/deployment.tsv"
printf '%s\n' "$deployment_mode" > "$run/deployment-mode"
printf '%s\n' "$target_root" > "$run/deployment-root"
for candidate in "${candidates[@]}"; do
    target="$target_root/${candidate#"$stage/"}"
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
date -u +%Y-%m-%dT%H:%M:%SZ > "$run/deployment-time"
date +%s%N > "$run/deployment-order"
printf '%s\n' "$run" >> "$target_root/$source_relative/.singularity-module-history"
deploying=1
for candidate in "${candidates[@]}"; do
    atomic_copy "$candidate" "$target_root/${candidate#"$stage/"}" 1
done
printf 'deployed\n' > "$run/deployment-state"
deploying=0
printf 'Deployment complete. Hidden backups retained; manifest: %s/deployment.tsv\n' "$run"
printf 'Restore with: bash %q --version %q --date-tag %q --stack-prefix %q' \
    "$PAWSEY_SPACK_CONFIG_REPO/scripts/update_singularity_modules.sh" "$version" "$date_tag" "$stack_prefix"
[ -z "$suffix" ] || printf ' --suffix %q' "$suffix"
if [ "$deployment_mode" = test ]; then
    printf ' --replace-in-test %q' "$test_run"
else
    printf ' --apply-live'
fi
printf ' --restore\n'
