#!/bin/bash
# Generate and validate custom SingularityCE module variants from software that
# is already installed in an existing Spack stack.
#
# The script uses the stack's Spack installation to discover installed specs and
# render fresh base modulefiles in a private per-run directory. It then generates
# requested custom flavours, stages their shared BASH_ENV compatibility patch
# files, validates every artifact, and either retains the testing output or
# publishes the validated files into the official stack.
#
# Workflow:
# 1) Parse and validate command-line options.
# 2) Load system settings and resolve canonical stack paths.
# 3) Create an isolated per-run staging directory below MYSCRATCH.
# 4) Discover installed SingularityCE specs and render private base modulefiles.
# 5) Generate requested variants and stage shared compatibility patch files.
# 6) Validate Lua and Bash syntax and evaluate modulefiles with Lmod.
# 7) Retain validated staging for testing, or publish validated files officially
#    with locking, conflict detection, and safe per-file replacement.
#
# Operational boundaries:
# - The script does not install software, concretize specs, or execute containers.
# - Installed package prefixes and Spack metadata are read-only inputs.
# - Privately rendered Spack base modulefiles are never published.
# - Testing mode leaves the installed stack unchanged and retains the full run.
# - Official mode publishes only custom variants and the two shared BASH_ENV
#   compatibility patch files.
# - Differing destinations require --force. No backup or rollback is performed,
#   so a publication failure may leave files published earlier in the loop changed.
# - Staging and logs are retained for inspection and troubleshooting.
#
# Designed by Alexis Espinosa and initially implemented with assistance from
# GPT-6.1 Sol via GitHub Copilot; reviewed and tested by Alexis Espinosa.
set -e -o pipefail

# Function for reporting a fatal error consistently and terminating the script.
die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# Function for printing syntax, options, operational notes, and usage examples.
usage() {
    cat <<'USAGE'
Usage: generate_singularity_modules.sh --install-type official|testing \
  --version VERSION|all [OPTIONS]

  --install-type TYPE   Required: official or testing.
  --version VERSION|all Generate one version, or all matching versions with "all".
  --flavour LIST        Comma-separated flavours to generate.
                        Choices: nompi, mpi, mpi-gpu, askap, askap-gpu, nohost, slurm.
                        Omit to generate all seven.
  --suffix LABEL        Append -LABEL to generated custom module names.
  --date-tag TAG        Stack release; defaults to DATE_TAG or the stack basename.
  --stack-prefix DIR    Existing Spack stack; defaults to settings.sh.
  --prefix DIR          Staging parent strictly below MYSCRATCH.
  --force               Replace differing destinations (official only).
  -h, --help            Show this help.

Examples:
  Validate all flavours for one installed version without publishing:
    generate_singularity_modules.sh --install-type testing --version 4.2.2

  Validate selected flavours with a suffix in a custom staging parent:
    generate_singularity_modules.sh --install-type testing --version 4.2.2 \
      --flavour mpi,mpi-gpu --suffix trial --prefix "$MYSCRATCH/module-testing"

  Publish all flavours for every installed SingularityCE version:
    generate_singularity_modules.sh --install-type official --version all

  Force replacement of reviewed conflicts for selected flavours:
    generate_singularity_modules.sh --install-type official --version 4.2.2 \
      --flavour mpi,mpi-gpu --force

Each run renders selected installed Spack modules into fresh private staging,
generates and validates only requested custom variants, then safely publishes
those variants and the two shared BASH_ENV compatibility patch files required
by the generated modules. Spack base modules are
never published. Identical destinations are reused; conflicts are reported
before publication. Existing destination files are not backed up or removed;
temporary publication files are cleaned up. No container runtime tests occur.
USAGE
}

# ------------------------------------------------------------------------------
# Step 1: parse and validate command-line arguments.
# ------------------------------------------------------------------------------
# Initialize option state, using supported environment defaults where available.
install_type=""
version=""
suffix=""
date_tag=${DATE_TAG:-${PAWSEY_STACK_VERSION:-}}
stack_override=""
prefix=""
force=0
flavour_option_seen=0
declare -a requested_flavours=()

# Parse long options explicitly so malformed or unsupported input fails early.
while [ "$#" -gt 0 ]; do
    case "$1" in
        --install-type|--version|--flavour|--suffix|--date-tag|--stack-prefix|--prefix)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                die "Missing value for $1."
            fi
            case "$1" in
                --install-type) install_type=$2 ;;
                --version)
                    [ -z "$version" ] || die "--version may be specified only once."
                    version=$2
                    ;;
                --flavour)
                    [ "$flavour_option_seen" -eq 0 ] ||
                        die "--flavour may be specified only once; use a comma-separated list."
                    [[ "$2" != ,* && "$2" != *, && "$2" != *,,* ]] ||
                        die "--flavour list must not contain empty entries."
                    IFS=, read -r -a requested_flavours <<< "$2"
                    flavour_option_seen=1
                    ;;
                --suffix) suffix=$2 ;;
                --date-tag) date_tag=$2 ;;
                --stack-prefix) stack_override=$2 ;;
                --prefix) prefix=$2 ;;
            esac
            shift 2
            ;;
        --force) force=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)." ;;
    esac
done

[[ "$install_type" = official || "$install_type" = testing ]] ||
    die "--install-type must be official or testing."
[ "$force" -eq 0 ] || [ "$install_type" = official ] ||
    die "--force is available only for official installation."
[ -n "$version" ] || die "Supply --version VERSION|all."
[[ "$version" = all || "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
    die "Supply --version VERSION|all."
[[ -z "$suffix" || "$suffix" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] ||
    die "--suffix must start with a letter or digit and contain only letters, digits, underscores, or hyphens."
for flavour in "${requested_flavours[@]}"; do
    case "$flavour" in
        nompi|mpi|mpi-gpu|askap|askap-gpu|nohost|slurm) ;;
        *) die "Unsupported --flavour: $flavour" ;;
    esac
done

# ------------------------------------------------------------------------------
# Step 2: load settings and resolve canonical input/output roots.
# ------------------------------------------------------------------------------
# Resolve the repository root and selected system configuration.
PAWSEY_SPACK_CONFIG_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SYSTEM=${SYSTEM:-${PAWSEY_CLUSTER:-setonix}}
[[ "$SYSTEM" =~ ^[A-Za-z0-9_-]+$ ]] || die "Invalid SYSTEM name."
if [ -z "$date_tag" ]; then
    if [ -n "$stack_override" ]; then
        date_tag=${stack_override%/}
        date_tag=${date_tag##*/}
    elif [ -n "${INSTALL_PREFIX:-}" ]; then
        date_tag=${INSTALL_PREFIX%/}
        date_tag=${date_tag##*/}
    else
        die "Set DATE_TAG or provide --stack-prefix."
    fi
fi
[[ "$date_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Invalid date tag."
if [ -n "$stack_override" ]; then
    INSTALL_PREFIX=$stack_override
elif [ -z "${INSTALL_PREFIX:-}" ]; then
    INSTALL_PREFIX="/software/$SYSTEM/$date_tag"
fi
export SYSTEM DATE_TAG="$date_tag" INSTALL_PREFIX
export INSTALL_GROUP="${INSTALL_GROUP:-$(id -gn)}"
# Settings use an include guard; clear an inherited guard so this process loads
# the selected system's definitions rather than silently skipping the file.
unset __PSC_SETTINGS__
# Export variables defined by settings.sh so Spack and other child processes
# inherit the selected system configuration.
set -a
# shellcheck source=/dev/null
. "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/settings.sh"
set +a

# Canonical paths make containment checks robust to relative inputs/symlinks.
stack_prefix=$(realpath -e "$INSTALL_PREFIX") || die "Stack prefix does not exist: $INSTALL_PREFIX"
[[ -d "$stack_prefix" ]] || die "Stack prefix is not a directory: $stack_prefix"
[ "$(id -u)" -ne 0 ] || die "Do not run this script as root."
[[ -n "${MYSCRATCH:-}" && -d "$MYSCRATCH" ]] || die "MYSCRATCH must be an existing directory."
scratch=$(realpath -e "$MYSCRATCH")

: "${cpu_arch:?Missing cpu_arch in settings.sh}"
: "${gcc_version:?Missing gcc_version in settings.sh}"
: "${python_name:?Missing python_name in settings.sh}"
: "${python_version:?Missing python_version in settings.sh}"
: "${singularity_name:?Missing singularity_name in settings.sh}"
: "${singularity_name_general:?Missing singularity_name_general in settings.sh}"
: "${singularity_symlink_module_dir:?Missing singularity_symlink_module_dir in settings.sh}"
# Derive and validate the relative module paths used for rendering and publication.
source_relative="modules/$cpu_arch/gcc/$gcc_version/utilities/$singularity_name_general"
variants_relative=$singularity_symlink_module_dir
for relative in "$source_relative" "$variants_relative"; do
    [[ "$relative" =~ ^[A-Za-z0-9._/-]+$ && ! "$relative" =~ (^|/)\.\.?(/|$) ]] ||
        die "Unsafe module directory from settings.sh: $relative"
done

# A missing flavour option means all supported outputs. Repeated names within
# the one comma-list are harmless, and are collapsed before invoking the generator.
# Expand the default flavour set or deduplicate the explicitly requested list.
if [ "${#requested_flavours[@]}" -eq 0 ]; then
    flavours=(nompi mpi mpi-gpu askap askap-gpu nohost slurm)
else
    flavours=()
    declare -A seen_flavours=()
    for flavour in "${requested_flavours[@]}"; do
        [ -n "${seen_flavours[$flavour]:-}" ] && continue
        seen_flavours[$flavour]=1
        flavours+=("$flavour")
    done
fi

# ------------------------------------------------------------------------------
# Step 3: allocate an isolated per-run staging directory.
# ------------------------------------------------------------------------------
# Resolve a safe staging prefix and allocate a unique retained run directory.
prefix=$(realpath -m "${prefix:-$scratch/singularity-module-updates/$DATE_TAG}")
[[ "$prefix" == "$scratch/"* && "$prefix" != "$scratch" ]] ||
    die "The staging prefix must be strictly below MYSCRATCH."
[[ "$prefix/" != "$stack_prefix/"* ]] || die "Keep staging outside the stack."
mkdir -p "$prefix"
[ -O "$prefix" ] || die "The staging prefix must belong to the current user."
run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
# Preserve the normal umask so retained modules can be inspected with Lmod.
run=$(mktemp -d "$prefix/$run_stamp-XXXXXXXX") ||
    die "Could not allocate a unique staging run below $prefix."
chmod "$(umask -S)" "$run"
stage="$run/tree"
rendered="$run/rendered"
mkdir -p "$stage" "$rendered"
printf 'Run directory: %s\nInstall type: %s\nStack prefix: %s\n' \
    "$run" "$install_type" "$stack_prefix"
printf 'Preparing private Spack rendering and installed-spec discovery; this may take a minute or two...\n'

# Track publication progress and temporary state for cleanup and diagnostics.
published_created=()
published_replaced=()
publication_started=0
file_temp=""
# Function for cleaning temporary publication state and reporting partial changes.
on_exit() {
    local status=$?
    if [ -n "$file_temp" ] && [ -e "$file_temp" ]; then
        rm -f -- "$file_temp"
    fi
    if [ "$status" -ne 0 ] && [ "$publication_started" -eq 1 ]; then
        printf 'Partial publication failed. Staging retained at: %s\n' "$run" >&2
        printf 'Files created: %s\n' "${published_created[*]:-none}" >&2
        printf 'Files replaced: %s\n' "${published_replaced[*]:-none}" >&2
    fi
}
# Run cleanup and partial-publication reporting whenever the script exits.
trap on_exit EXIT

# ------------------------------------------------------------------------------
# Step 4: build private Spack config roots and render selected base modules.
# ------------------------------------------------------------------------------
spack="$stack_prefix/spack/bin/realspack"
[ -x "$spack" ] || die "Installed Spack executable not found: $spack"
generator="$PAWSEY_SPACK_CONFIG_REPO/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"
mkdir -p "$run/templates" "$run/site" "$run/staff" \
    "$run/overrides" "$run/cache" "$rendered/$source_relative"
# Copy templates and module configuration into the private run for safe rewriting.
cp -R "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/." "$run/templates/"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/site/modules.yaml" "$run/site/"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/spackuser/modules.yaml" "$run/staff/"
sed -i \
    -e "s|INSTALL_PREFIX|$stack_prefix|g" \
    -e "s|DATE_TAG|$DATE_TAG|g" \
    -e "s|USER_PERMANENT_FILES_PREFIX|$USER_PERMANENT_FILES_PREFIX|g" \
    -e "s|USER_TEMP_FILES_PREFIX|$USER_TEMP_FILES_PREFIX|g" \
    -e "s|BOOTSTRAP_PATH|$BOOTSTRAP_PATH|g" \
    "$run/templates/modules/modulefile.lua" "$run/site/modules.yaml" "$run/staff/modules.yaml"

cat > "$run/overrides/config.yaml" <<EOF
config:
  install_tree:
    root: '$stack_prefix/software'
  template_dirs::
    - '$run/templates'
  misc_cache: '$run/cache/misc'
  source_cache: '$run/cache/sources'
EOF
# Use repositories from the selected stack, not developer-local Spack config.
cat > "$run/overrides/modules.yaml" <<EOF
modules:
  default:
    roots:
      lmod: '$rendered/modules'
EOF
printf 'upstreams:: {}\n' > "$run/overrides/upstreams.yaml"
printf 'bootstrap:\n  enable: false\n' > "$run/overrides/bootstrap.yaml"
builtin="$stack_prefix/spack/var/spack/repos/builtin/repos/spack_repo/builtin"
pawsey="$stack_prefix/spack/var/spack/repos/pawsey"
[[ -f "$builtin/repo.yaml" && -f "$pawsey/repo.yaml" ]] ||
    die "Installed Spack recipe repositories are missing."
cat > "$run/overrides/repos.yaml" <<EOF
repos::
  pawsey_repo: '$pawsey'
  builtin: '$builtin'
EOF

export SPACK_DISABLE_LOCAL_CONFIG=1
export SPACK_USER_CONFIG_PATH="$run/user-config"
export SPACK_USER_CACHE_PATH="$run/cache/user"
export SPACK_SYSTEM_CONFIG_PATH="$run/system-config"
export PYTHONDONTWRITEBYTECODE=1
# Prevent site/user startup hooks from writing to stdout during `spack python`.
# Any banner text would pollute path parsing and break deterministic checks.
export PYTHONSTARTUP=""
# -E ignores ambient SPACK_* state; explicit roots keep this run deterministic.
# Build one Spack command prefix that always uses isolated configuration.
spack_command=("$spack" -E -C "$run/site" -C "$run/staff" -C "$run/overrides")
type module >/dev/null 2>&1 || die "The Lmod module command must be available."
# Load the stack Python required by Spack's renderer (child shell only).
module use "$stack_prefix/modules/$cpu_arch/gcc/$gcc_version/programming-languages"
module load "$python_name/$python_version"
SPACK_PYTHON=$(command -v python3) || die "The stack Python module did not expose python3."
export SPACK_PYTHON

# 5. Query/filter installed specs and reject ambiguous module-version mappings.
query="$singularity_name_general"
[ "$version" = all ] || query+="@=$version"
"${spack_command[@]}" find --format '{hash} {prefix} {compiler.name} {compiler.version} {version}' \
    "$query target=$cpu_arch" > "$run/installed-specs.txt"
declare -a hashes=() package_prefixes=() versions=()
while read -r hash package_prefix compiler compiler_version module_version; do
    if [ "$compiler" = gcc ] && [ "$compiler_version" = "$gcc_version" ]; then
        hashes+=("$hash")
        package_prefixes+=("$package_prefix")
        versions+=("$module_version")
    fi
done < "$run/installed-specs.txt"
if [ "${#hashes[@]}" -eq 0 ] ||
    { [ "$version" != all ] && [ "${#hashes[@]}" -ne 1 ]; }; then
    die "Expected installed $query for $cpu_arch/GCC $gcc_version; found ${#hashes[@]}. See $run/installed-specs.txt."
fi

# Render and verify one deterministic private base module per selected version.
declare -A output_versions=()
for index in "${!hashes[@]}"; do
    hash=${hashes[$index]}
    package_prefix=${package_prefixes[$index]}
    module_version=${versions[$index]}
    [[ "$hash" =~ ^[a-z0-9]+$ && "$module_version" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
        die "Spack returned an invalid installed spec."
    if [ "$version" != all ] && [ "$module_version" != "$version" ]; then
        die "Spack returned version $module_version for requested version $version."
    fi
    real_package_prefix=$(realpath -e "$package_prefix") ||
        die "Installed package prefix does not exist: $package_prefix"
    [[ "$real_package_prefix" == "$stack_prefix/software/"* ]] ||
        die "Selected spec is not installed inside this stack: $package_prefix"
    [ -z "${output_versions[$module_version]:-}" ] ||
        die "Installed specs ${output_versions[$module_version]} and $hash both map to module version $module_version."
    output_versions[$module_version]=$hash
    # Verify Spack writes only under the private render root.
    resolved_output=$("${spack_command[@]}" python -c \
        "import spack.store, spack.modules.lmod; spec = spack.store.STORE.db.query('/$hash')[0]; print(spack.modules.lmod.LmodModulefileWriter(spec, 'default').layout.filename)")
    resolved=$(printf '%s\n' "$resolved_output" | tail -n 1)
    expected="$rendered/$source_relative/$module_version.lua"
    [[ "$resolved" = "$expected" ]] ||
        die "Spack resolved an unexpected output path: $resolved_output"
    "${spack_command[@]}" module lmod refresh -y "/$hash" 2>&1 |
        tee -a "$run/spack-refresh.log"
    [ -s "$expected" ] || die "Spack did not produce the expected source module: $expected"
    # Catch stale-template and wrong-spec outputs before variant generation.
    if grep -Eq '\{\{|\{%' "$expected"; then
        die "Source module contains unrendered template expressions: $expected"
    fi
    grep -Fq "$real_package_prefix/bin" "$expected" ||
        die "Source module does not reference the installed binary: $expected"
done

printf 'Generating requested variants from rendered base modules...\n'

# ------------------------------------------------------------------------------
# Step 5: generate requested custom variants and stage the shared BASH_ENV compatibility patch files.
# ------------------------------------------------------------------------------
# Prepare the variant staging directory, collect the rendered base modulefiles,
# and initialize the artifact tracking arrays and generation log.
variant_directory="$stage/$variants_relative"
mkdir -p "$variant_directory"
shopt -s nullglob
base_modules=("$rendered/$source_relative/"*.lua)
[ "${#base_modules[@]}" -gt 0 ] || die "Spack rendered no installed base modules."
declare -a candidates=() target_relatives=() generated_module_names=()
variant_log="$run/variant-generation.log"
: > "$variant_log"

# Generate each requested flavour from every rendered base module, normalize its
# provenance header, and record the staged candidate and publication metadata.
for base_module in "${base_modules[@]}"; do
    module_version=${base_module##*/}
    module_version=${module_version%.lua}
    for flavour in "${flavours[@]}"; do
        variant_args=(
            --input-dir "$rendered/$source_relative"
            --output-dir "$variant_directory"
            --version "$module_version" --flavour "$flavour"
        )
        [ -z "$suffix" ] || variant_args+=(--suffix "$suffix")
        filename="$module_version-$flavour${suffix:+-$suffix}.lua"
        printf 'Generate module_version=%s flavour=%s output=%s\n' \
            "$module_version" "$flavour" "$variant_directory/$filename" >> "$variant_log"
        "$generator" "${variant_args[@]}" >> "$variant_log" 2>&1 ||
            die "Variant generation failed; see $variant_log"

        # Keep stable provenance without a generation timestamp.
        sed -i \
            -e '/^-- Module file created by spack /s/ on .*//' \
            -e '/^-- Module file created by spack /a\
-- Customized by PawseySC/pawsey-spack-config:\
--   scripts/generate_singularity_modules.sh (driver)\
--   scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh (flavour transformations)' \
            "$variant_directory/$filename"

        candidates+=("$variant_directory/$filename")
        target_relatives+=("$variants_relative/$filename")
        module_name="$singularity_name/${filename%.lua}"
        generated_module_names+=("$module_name")
    done
done

# Report module candidates before shared patch files join the candidate list.
printf 'Generated staged module candidates under:\n'
printf '  %s\n' "$variant_directory"
printf 'Staged module candidates:\n'
for index in "${!generated_module_names[@]}"; do
    printf '  %s -> %s\n' \
        "${generated_module_names[$index]}" "${candidates[$index]##*/}"
done

# Stage the shared BASH_ENV compatibility patch files and register them as
# validation and publication candidates.
bash_env_patch_directory="$stage/pawsey/lmod-variable-fixes"
mkdir -p "$bash_env_patch_directory"
for bash_env_patch_file in pawsey_fix_initial_bash.lua pawsey_init_bash; do
    cp -p -- "$PAWSEY_SPACK_CONFIG_REPO/scripts/$bash_env_patch_file" "$bash_env_patch_directory/$bash_env_patch_file"
    candidates+=("$bash_env_patch_directory/$bash_env_patch_file")
    target_relatives+=("pawsey/lmod-variable-fixes/$bash_env_patch_file")
done

printf 'Validating generated modules and BASH_ENV compatibility patch files...\n'

# ------------------------------------------------------------------------------
# Step 6: validate staged artifacts before any official publication.
# ------------------------------------------------------------------------------
# Require the Lua compiler for syntax-checking generated modulefiles and patch files.
command -v luac >/dev/null 2>&1 ||
    die "luac is required to validate generated modulefiles and patch files."

# Select the modulefiles used for Lmod validation. Use the staged candidates when
# the installed BASH_ENV compatibility patches are readable; otherwise create
# disposable copies that reference the staged patches, leaving candidates unchanged.
variant_module_root=$(dirname "$variant_directory")
validation_directory=$variant_directory
if [ ! -r "$stack_prefix/pawsey/lmod-variable-fixes/pawsey_fix_initial_bash.lua" ] ||
    [ ! -r "$stack_prefix/pawsey/lmod-variable-fixes/pawsey_init_bash" ]; then
    # A fresh stack cannot evaluate the template's patch path until publication.
    # Only disposable validation copies use staged patches; candidates stay intact.
    validation_directory="$run/validation/$singularity_name"
    mkdir -p "$validation_directory"
    cp -- "$variant_directory/"*.lua "$validation_directory/"
    sed -i \
        "s|^local patch_dir = .*|local patch_dir = \"$bash_env_patch_directory\"|" \
        "$validation_directory/"*.lua
    printf 'Installed BASH_ENV compatibility patches are missing or unreadable.\n'
    printf 'Lmod checks will use disposable copies with staged patches: %s\n' "$validation_directory"
    printf 'Deliverable modulefiles are unchanged; loading them requires patches at: %s\n' \
        "$stack_prefix/pawsey/lmod-variable-fixes"
fi

# Validate every staged candidate with the parser appropriate to its file type.
# Generated modulefiles also undergo Lmod resolution and evaluation checks to
# confirm that Lmod selects and successfully evaluates the intended staged file.
for index in "${!candidates[@]}"; do
    candidate=${candidates[$index]}
    [ -s "$candidate" ] || die "Empty generated candidate: $candidate"
    if [[ "$candidate" == "$variant_directory/"* ]]; then
        luac -p "$candidate"
        module_name="$singularity_name/${candidate##*/}"
        module_name=${module_name%.lua}
        validation_candidate="$validation_directory/${candidate##*/}"
        (
            # This subshell is in an OR-list, where Bash disables errexit.
            module unload "$singularity_name" || exit 1
            module use "$(dirname "$validation_directory")" || exit 1
            location=$(module --ignore-cache --redirect --location show "$module_name") || exit 1
            [ "$location" = "$validation_candidate" ] || {
                printf 'Lmod selected a non-staged module: %s\n' "$location" >&2
                exit 1
            }
            module --ignore-cache --redirect show "$module_name"
        ) > "$run/${candidate##*/}.show.log" 2>&1 ||
            die "Lmod validation failed; see $run/${candidate##*/}.show.log"
    elif [[ "$candidate" == "$bash_env_patch_directory/"*.lua ]]; then
        luac -p "$candidate"
    else
        bash -n "$candidate"
    fi
done

bash_env_patch_file_count=2
variant_count=$((${#candidates[@]} - bash_env_patch_file_count))
printf 'Validated staged artifacts:\n'
printf '  Custom module candidates: %s\n' "$variant_count"
printf '  BASH_ENV compatibility patch files: %s\n' "$bash_env_patch_file_count"

# For testing installations, report the validated staged artifacts and example
# module commands, retain the complete run for inspection, and exit without
# publishing any files to the installed stack.
if [ "$install_type" = testing ]; then
    # Testing is intentionally side-effect free on the installed stack.
    printf 'Generated variants directory: %s\n' "$variant_directory"
    printf 'Generated BASH_ENV compatibility patch directory: %s\n' "$bash_env_patch_directory"
    printf 'Generated module names:\n'
    for module_name in "${generated_module_names[@]}"; do
        printf '  %s\n' "$module_name"
    done
    if [ "${#generated_module_names[@]}" -gt 0 ]; then
        printf 'Example staged usage:\n'
        printf '  module use %q\n' "$variant_module_root"
        printf '  module load %q\n' "${generated_module_names[0]}"
        printf '  module --ignore-cache show %q\n' "${generated_module_names[0]}"
    fi
    printf 'Next actions:\n'
    printf '  1) Inspect staged modules under: %s\n' "$variant_directory"
    printf '  2) Load from staging with the example commands above.\n'
    printf '  3) After functional testing, copy the modulefiles unchanged to: %s\n' \
        "$stack_prefix/$variants_relative"
    printf '     Alternatively, re-run with --install-type official.\n'
    printf 'Required installed BASH_ENV compatibility patches: %s\n' \
        "$stack_prefix/pawsey/lmod-variable-fixes"
    printf 'Logs:\n  %s\n  %s\n' "$run/spack-refresh.log" "$variant_log"
    printf 'Testing output retained without publishing: %s\n' "$run"
    exit 0
fi

# ------------------------------------------------------------------------------
# Step 7: publish officially with lock, preflight, and atomic per-file writes.
# ------------------------------------------------------------------------------
# Use flock to acquire an exclusive lock and serialize official publication,
# ensuring that only one process modifies the stack at a time.
command -v flock >/dev/null 2>&1 || die "flock is required for safe publication."
lock_file="$stack_prefix/.singularity-module-update.lock"
[ ! -L "$lock_file" ] || die "Refusing a symlink lock path: $lock_file"
exec 9>>"$lock_file"
flock -x 9

# Function for validating a relative publication path and safely creating its
# parent directories under the stack prefix without following symlinks.
ensure_safe_parent() {
    local relative=$1 current=$stack_prefix component
    local -a components
    [[ "$relative" =~ ^[A-Za-z0-9._/-]+$ && ! "$relative" =~ (^|/)\.\.?(/|$) ]] ||
        die "Unsafe target path: $relative"
    IFS=/ read -r -a components <<< "${relative%/*}"
    for component in "${components[@]}"; do
        [ -n "$component" ] || continue
        current="$current/$component"
        # Reject symlinks at every level; otherwise a seemingly in-stack target
        # could redirect publication to an unrelated tree.
        [ ! -L "$current" ] || die "Refusing symlink target directory: $current"
        if [ -e "$current" ]; then
            [ -d "$current" ] || die "Target parent is not a directory: $current"
        else
            mkdir -- "$current"
            if [ -L "$current" ] || [ ! -d "$current" ]; then
                die "Target directory changed during creation: $current"
            fi
        fi
    done
}

# Build a complete publication plan before changing any destination file. Record
# whether each target is identical, missing, or conflicting with its candidate.
declare -a conflicts=() bash_env_patch_conflicts=() target_paths=() planned_states=()
for index in "${!candidates[@]}"; do
    candidate=${candidates[$index]}
    relative=${target_relatives[$index]}
    ensure_safe_parent "$relative"
    target="$stack_prefix/$relative"
    [ ! -L "$target" ] || die "Refusing symlink destination: $target"
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "Destination is not a regular file: $target"
        if cmp -s -- "$candidate" "$target"; then
            planned_states+=(identical)
        else
            conflicts+=("$target")
            [[ "$relative" == pawsey/lmod-variable-fixes/* ]] &&
                bash_env_patch_conflicts+=("$target")
            planned_states+=(conflict)
        fi
    else
        planned_states+=(missing)
    fi
    target_paths+=("$target")
done
# Report every planned action before enforcing conflicts or modifying the stack.
printf 'Publication plan:\n'
for index in "${!candidates[@]}"; do
    case "${planned_states[$index]}" in
        identical) printf '  reuse     %s\n' "${target_paths[$index]}" ;;
        missing) printf '  create    %s\n' "${target_paths[$index]}" ;;
        conflict) printf '  conflict  %s\n' "${target_paths[$index]}" ;;
    esac
done
# Stop before publication if any existing destination differs from its staged
# candidate and --force was not specified.
if [ "${#conflicts[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
    printf 'ERROR: Differing destinations were found; no files were published:\n' >&2
    printf '  %s\n' "${conflicts[@]}" >&2
    if [ "${#bash_env_patch_conflicts[@]}" -gt 0 ]; then
        printf 'A shared BASH_ENV compatibility patch conflict affects every generated module.\n' >&2
    fi
    die "Use --force only for an official installation to replace these files."
fi
# Warn before force-replacing shared BASH_ENV compatibility patch files because
# the change may affect installed Singularity modules outside the current update.
if [ "${#bash_env_patch_conflicts[@]}" -gt 0 ]; then
    printf 'WARNING: This forced publication will replace shared BASH_ENV compatibility patch files.\n' >&2
    printf 'The change may affect every installed Singularity module that uses these files, not only the modules updated by this run:\n' >&2
    printf '  %s\n' "${bash_env_patch_conflicts[@]}" >&2
fi

# Publish each validated file safely, one at a time. Each destination changes
# from the complete old file to the complete new file without exposing a partial
# copy. If a later publication fails, files published earlier remain changed.
publication_started=1
printf 'Publishing validated variants and BASH_ENV compatibility patch files into the official tree...\n'
for index in "${!candidates[@]}"; do
    candidate=${candidates[$index]}
    target=${target_paths[$index]}
    [ ! -L "$target" ] || die "Refusing symlink destination: $target"
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "Destination is not a regular file: $target"
        if cmp -s -- "$candidate" "$target"; then
            printf 'Reused identical file: %s\n' "$target"
            continue
        fi
        [ "$force" -eq 1 ] || die "Destination changed during publication (not overwritten): $target"
        state=replaced
    else
        state=created
    fi
    # Reserve beside the destination for atomic rename/link publication.
    file_temp=$(mktemp "${target%/*}/.${target##*/}.publish.XXXXXXXX") ||
        die "Could not allocate a publication file beside $target."
    cp -p -- "$candidate" "$file_temp"
    if [ "$state" = replaced ]; then
        if mv -fT -- "$file_temp" "$target"; then
            published_replaced+=("$target")
            file_temp=""
            printf 'Replaced: %s\n' "$target"
        else
            die "Could not atomically replace: $target"
        fi
    else
        # A hard link creates a previously absent target without overwriting a
        # file that raced into place after preflight.
        if ln -T -- "$file_temp" "$target"; then
            rm -f -- "$file_temp"
            file_temp=""
            published_created+=("$target")
            printf 'Created: %s\n' "$target"
        else
            rm -f -- "$file_temp"
            file_temp=""
            [ ! -L "$target" ] || die "Refusing symlink destination: $target"
            if [ -f "$target" ] && cmp -s -- "$candidate" "$target"; then
                printf 'Reused identical file after concurrent creation: %s\n' "$target"
            else
                die "Destination appeared during publication and was not overwritten: $target"
            fi
        fi
    fi
done
# Mark publication as successfully completed so the exit handler no longer
# reports a partial publication, then print the final results and usage details.
publication_started=0
printf 'Publication complete. Created: %s; replaced: %s; reused: %s.\n' \
    "${#published_created[@]}" "${#published_replaced[@]}" \
    "$((${#candidates[@]} - ${#published_created[@]} - ${#published_replaced[@]}))"
printf 'Published variants directory: %s\n' "$stack_prefix/$variants_relative"
printf 'Published BASH_ENV compatibility patch directory: %s\n' "$stack_prefix/pawsey/lmod-variable-fixes"
printf 'Published module names:\n'
for module_name in "${generated_module_names[@]}"; do
    printf '  %s\n' "$module_name"
done
if [ "${#generated_module_names[@]}" -gt 0 ]; then
    printf 'Next actions:\n'
    printf '  1) module use %q\n' "$(dirname "$stack_prefix/$variants_relative")"
    printf '  2) module load %q\n' "${generated_module_names[0]}"
    printf '  3) module --ignore-cache show %q\n' "${generated_module_names[0]}"
fi
printf 'Logs:\n  %s\n  %s\n' "$run/spack-refresh.log" "$variant_log"
printf 'Staging and validation logs retained at: %s\n' "$run"
