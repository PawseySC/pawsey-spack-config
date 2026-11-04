#!/bin/bash
# Generate and validate custom Singularity module variants from the SingularityCE that
# is already installed in an existing Spack stack.
#
# The script reuses the selected stack's Spack executable, installed-spec database,
# package tree, recipe repositories, and Python. It does not create another Spack
# installation. Instead, it isolates module rendering with private templates,
# configuration, caches, and output directories under a retained per-run workspace.
# Bash first resolves Pawsey-specific placeholders in private copies of the template
# and module configuration; Spack then evaluates the template against each selected
# installed SingularityCE spec to render a concrete private base modulefile.
#
# The script then generates the requested custom flavours, stages their shared
# BASH_ENV compatibility patch files, validates every artifact, and either retains
# the testing output or publishes the validated files into the official stack.
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
# Note:
# Designed by Alexis Espinosa and developed with assistance from GitHub Copilot
# using Fusion + Intelligence model routing; reviewed and tested by Alexis Espinosa.

# Set to exit on unhandled command or pipeline failures to avoid continuing after an incomplete step.
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

  Compulsory options:
  --version VERSION|all Generate one version, or all matching versions with "all".

  Options:
  --install-type TYPE   Required: official or testing.
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
stack_dir_override=""
staging_parent_dir=""
force=0
flavour_option_seen=0
declare -a requested_flavours_arr=()

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
                    IFS=, read -r -a requested_flavours_arr <<< "$2"
                    flavour_option_seen=1
                    ;;
                --suffix) suffix=$2 ;;
                --date-tag) date_tag=$2 ;;
                --stack-prefix) stack_dir_override=$2 ;;
                --prefix) staging_parent_dir=$2 ;;
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
for flavour in "${requested_flavours_arr[@]}"; do
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
    if [ -n "$stack_dir_override" ]; then
        date_tag=${stack_dir_override%/}
        date_tag=${date_tag##*/}
    elif [ -n "${INSTALL_PREFIX:-}" ]; then
        date_tag=${INSTALL_PREFIX%/}
        date_tag=${date_tag##*/}
    else
        die "Set DATE_TAG or provide --stack-prefix."
    fi
fi
[[ "$date_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Invalid date tag."
if [ -n "$stack_dir_override" ]; then
    INSTALL_PREFIX=$stack_dir_override
elif [ -z "${INSTALL_PREFIX:-}" ]; then
    INSTALL_PREFIX="/software/$SYSTEM/$date_tag"
fi
export SYSTEM DATE_TAG="$date_tag" INSTALL_PREFIX
export INSTALL_GROUP="${INSTALL_GROUP:-$(id -gn)}"
# Load the selected system configuration into this script process.
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# Canonical paths make containment checks robust to relative inputs/symlinks.
stack_dir=$(realpath -e "$INSTALL_PREFIX") || die "Stack prefix does not exist: $INSTALL_PREFIX"
[[ -d "$stack_dir" ]] || die "Stack prefix is not a directory: $stack_dir"
[ "$(id -u)" -ne 0 ] || die "Do not run this script as root."
[[ -n "${MYSCRATCH:-}" && -d "$MYSCRATCH" ]] || die "MYSCRATCH must be an existing directory."
scratch_dir=$(realpath -e "$MYSCRATCH")

# Require all settings used to construct Spack, Python, and Singularity paths and names.
: "${cpu_arch:?Missing cpu_arch in settings.sh}"
: "${gcc_version:?Missing gcc_version in settings.sh}"
: "${python_name:?Missing python_name in settings.sh}"
: "${python_version:?Missing python_version in settings.sh}"
: "${singularity_name:?Missing singularity_name in settings.sh}"
: "${singularity_name_general:?Missing singularity_name_general in settings.sh}"
: "${singularity_symlink_module_dir:?Missing singularity_symlink_module_dir in settings.sh}"

# Derive and validate the relative module paths used for rendering and publication.
source_module_relative_dir="modules/$cpu_arch/gcc/$gcc_version/utilities/$singularity_name_general"
variant_module_relative_dir=$singularity_symlink_module_dir
for target_relative in "$source_module_relative_dir" "$variant_module_relative_dir"; do
    [[ "$target_relative" =~ ^[A-Za-z0-9._/-]+$ && ! "$target_relative" =~ (^|/)\.\.?(/|$) ]] ||
        die "Unsafe module directory from settings.sh: $target_relative"
done

# A missing flavour option means all supported outputs. Repeated names within
# the one comma-list are harmless, and are collapsed before invoking the generator.
# Expand the default flavour set or deduplicate the explicitly requested list.
if [ "${#requested_flavours_arr[@]}" -eq 0 ]; then
    flavours_arr=(nompi mpi mpi-gpu askap askap-gpu nohost slurm)
else
    flavours_arr=()
    declare -A seen_flavours_map=()
    for flavour in "${requested_flavours_arr[@]}"; do
        [ -n "${seen_flavours_map[$flavour]:-}" ] && continue
        seen_flavours_map[$flavour]=1
        flavours_arr+=("$flavour")
    done
fi

# ------------------------------------------------------------------------------
# Step 3: allocate an isolated per-run staging directory.
# ------------------------------------------------------------------------------
# Resolve a safe staging prefix and allocate a unique retained run directory.
staging_parent_dir=$(realpath -m "${staging_parent_dir:-$scratch_dir/singularity-module-updates/$DATE_TAG}")
[[ "$staging_parent_dir" == "$scratch_dir/"* && "$staging_parent_dir" != "$scratch_dir" ]] ||
    die "The staging prefix must be strictly below MYSCRATCH."
[[ "$staging_parent_dir/" != "$stack_dir/"* ]] || die "Keep staging outside the stack."
mkdir -p "$staging_parent_dir"
[ -O "$staging_parent_dir" ] || die "The staging prefix must belong to the current user."
run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
# Preserve the normal umask so retained modules can be inspected with Lmod.
run_dir=$(mktemp -d "$staging_parent_dir/$run_stamp-XXXXXXXX") ||
    die "Could not allocate a unique staging run below $staging_parent_dir."
chmod "$(umask -S)" "$run_dir"
stage_dir="$run_dir/tree"
rendered_dir="$run_dir/rendered"
mkdir -p "$stage_dir" "$rendered_dir"
printf 'Run directory: %s\nInstall type: %s\nStack prefix: %s\n' \
    "$run_dir" "$install_type" "$stack_dir"
printf 'Preparing private Spack rendering and installed-spec discovery; this may take a minute or two...\n'

# Track publication progress and temporary state for cleanup and diagnostics.
published_created_arr=()
published_replaced_arr=()
publication_started=0
publication_temp_file=""
# Function for cleaning temporary publication state and reporting partial changes.
on_exit() {
    local status=$?
    if [ -n "$publication_temp_file" ] && [ -e "$publication_temp_file" ]; then
        rm -f -- "$publication_temp_file"
    fi
    if [ "$status" -ne 0 ] && [ "$publication_started" -eq 1 ]; then
        printf 'Partial publication failed. Staging retained at: %s\n' "$run_dir" >&2
        printf 'Files created: %s\n' "${published_created_arr[*]:-none}" >&2
        printf 'Files replaced: %s\n' "${published_replaced_arr[*]:-none}" >&2
    fi
}
# Run cleanup and partial-publication reporting whenever the script exits.
trap on_exit EXIT

# ------------------------------------------------------------------------------
# Step 4: build private Spack config roots and render selected base modules.
# ------------------------------------------------------------------------------
# Reuse the selected stack's Spack executable, installed-spec database, package
# tree, recipe repositories, and Python, while directing configuration, templates,
# caches, and rendered modulefiles into the current private run.

spack_executable="$stack_dir/spack/bin/realspack"
[ -x "$spack_executable" ] || die "Installed Spack executable not found: $spack_executable"
creator_script="$PAWSEY_SPACK_CONFIG_REPO/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"
mkdir -p "$run_dir/templates" "$run_dir/site" "$run_dir/staff" \
    "$run_dir/overrides" "$run_dir/cache" "$rendered_dir/$source_module_relative_dir"

# Copy the selected templates and module configuration into the private run, then
# resolve Pawsey-specific placeholders before Spack evaluates the template against
# each selected installed spec.
cp -R "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/." "$run_dir/templates/"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/site/modules.yaml" "$run_dir/site/"
cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/spackuser/modules.yaml" "$run_dir/staff/"
sed -i \
    -e "s|INSTALL_PREFIX|$stack_dir|g" \
    -e "s|DATE_TAG|$DATE_TAG|g" \
    -e "s|USER_PERMANENT_FILES_PREFIX|$USER_PERMANENT_FILES_PREFIX|g" \
    -e "s|USER_TEMP_FILES_PREFIX|$USER_TEMP_FILES_PREFIX|g" \
    -e "s|BOOTSTRAP_PATH|$BOOTSTRAP_PATH|g" \
    "$run_dir/templates/modules/modulefile.lua" "$run_dir/site/modules.yaml" "$run_dir/staff/modules.yaml"

# Build the private Spack configuration used to render modulefiles from the
# selected installed stack without using developer-local configuration or
# writing generated modules and caches outside the current run directory.
#
# Reference the installed package tree while directing template lookup and
# cache writes into the current run directory.
cat > "$run_dir/overrides/config.yaml" <<EOF
config:
  install_tree:
    root: '$stack_dir/software'
  template_dirs::
    - '$run_dir/templates'
  misc_cache: '$run_dir/cache/misc'
  source_cache: '$run_dir/cache/sources'
EOF
# Direct privately rendered Lmod modulefiles into the current run directory.
cat > "$run_dir/overrides/modules.yaml" <<EOF
modules:
  default:
    roots:
      lmod: '$rendered_dir/modules'
EOF
# Disable upstreams and bootstrapping so rendering relies only on software and
# tooling already available in the selected stack.
printf 'upstreams:: {}\n' > "$run_dir/overrides/upstreams.yaml"
printf 'bootstrap:\n  enable: false\n' > "$run_dir/overrides/bootstrap.yaml"
# Locate and validate the recipe repositories installed with the selected stack,
# then configure Spack to use only those repositories for this private run.
builtin_repo_dir="$stack_dir/spack/var/spack/repos/builtin/repos/spack_repo/builtin"
pawsey_repo_dir="$stack_dir/spack/var/spack/repos/pawsey"
[[ -f "$builtin_repo_dir/repo.yaml" && -f "$pawsey_repo_dir/repo.yaml" ]] ||
    die "Installed Spack recipe repositories are missing."
cat > "$run_dir/overrides/repos.yaml" <<EOF
repos::
  pawsey_repo: '$pawsey_repo_dir'
  builtin: '$builtin_repo_dir'
EOF

# Prepare an isolated execution environment for the private Spack commands and
# select the stack Python interpreter required for modulefile rendering.
#
# Isolate Spack and Python from ambient user configuration, redirect writable
# state into the current run, and suppress output that could corrupt path parsing.
export SPACK_DISABLE_LOCAL_CONFIG=1
export SPACK_USER_CONFIG_PATH="$run_dir/user-config"
export SPACK_USER_CACHE_PATH="$run_dir/cache/user"
export SPACK_SYSTEM_CONFIG_PATH="$run_dir/system-config"
export PYTHONDONTWRITEBYTECODE=1
export PYTHONSTARTUP=""
# Build a reusable Spack command that ignores ambient SPACK_* state and applies
# only the explicit site, staff, and private override configuration roots.
spack_command_arr=("$spack_executable" -E -C "$run_dir/site" -C "$run_dir/staff" -C "$run_dir/overrides")
# Load the stack Python required by Spack, then export its interpreter path for
# the private rendering commands executed by this script.
type module >/dev/null 2>&1 || die "The Lmod module command must be available."
module use "$stack_dir/modules/$cpu_arch/gcc/$gcc_version/programming-languages"
module load "$python_name/$python_version"
SPACK_PYTHON=$(command -v python3) || die "The stack Python module did not expose python3."
export SPACK_PYTHON

# Query installed SingularityCE specs, retain those built with the configured GCC
# and target architecture, and reject missing or ambiguous version selections.
query="$singularity_name_general"
[ "$version" = all ] || query+="@=$version"
"${spack_command_arr[@]}" find --format '{hash} {prefix} {compiler.name} {compiler.version} {version}' \
    "$query target=$cpu_arch" > "$run_dir/installed-specs.txt"
declare -a hashes_arr=() package_prefix_dirs_arr=() versions_arr=()
while read -r hash package_prefix_dir compiler compiler_version module_version; do
    if [ "$compiler" = gcc ] && [ "$compiler_version" = "$gcc_version" ]; then
        hashes_arr+=("$hash")
        package_prefix_dirs_arr+=("$package_prefix_dir")
        versions_arr+=("$module_version")
    fi
done < "$run_dir/installed-specs.txt"
if [ "${#hashes_arr[@]}" -eq 0 ] ||
    { [ "$version" != all ] && [ "${#hashes_arr[@]}" -ne 1 ]; }; then
    die "Expected installed $query for $cpu_arch/GCC $gcc_version; found ${#hashes_arr[@]}. See $run_dir/installed-specs.txt."
fi

# Render and verify one deterministic private base module per selected version.
declare -A output_versions_map=()
for index in "${!hashes_arr[@]}"; do
    hash=${hashes_arr[$index]}
    package_prefix_dir=${package_prefix_dirs_arr[$index]}
    module_version=${versions_arr[$index]}
    # Validate the selected spec and confirm that its installed package prefix belongs
    # to the current stack and maps uniquely to the requested module version.
    [[ "$hash" =~ ^[a-z0-9]+$ && "$module_version" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
        die "Spack returned an invalid installed spec."
    if [ "$version" != all ] && [ "$module_version" != "$version" ]; then
        die "Spack returned version $module_version for requested version $version."
    fi
    real_package_prefix_dir=$(realpath -e "$package_prefix_dir") ||
        die "Installed package prefix does not exist: $package_prefix_dir"
    [[ "$real_package_prefix_dir" == "$stack_dir/software/"* ]] ||
        die "Selected spec is not installed inside this stack: $package_prefix_dir"
    [ -z "${output_versions_map[$module_version]:-}" ] ||
        die "Installed specs ${output_versions_map[$module_version]} and $hash both map to module version $module_version."
    output_versions_map[$module_version]=$hash
    # Verify Spack writes only under the private render root.
    spack_resolution_output=$("${spack_command_arr[@]}" python -c \
        "import spack.store, spack.modules.lmod; spec = spack.store.STORE.db.query('/$hash')[0]; print(spack.modules.lmod.LmodModulefileWriter(spec, 'default').layout.filename)")
    resolved_modulefile=$(printf '%s\n' "$spack_resolution_output" | tail -n 1)
    expected_modulefile="$rendered_dir/$source_module_relative_dir/$module_version.lua"
    [[ "$resolved_modulefile" = "$expected_modulefile" ]] ||
        die "Spack resolved an unexpected output path: $spack_resolution_output"
    # Render the base modulefile for the exact installed spec and confirm that Spack
    # created the expected nonempty file in the private module tree.
    "${spack_command_arr[@]}" module lmod refresh -y "/$hash" 2>&1 |
        tee -a "$run_dir/spack-refresh.log"
    [ -s "$expected_modulefile" ] || die "Spack did not produce the expected source module: $expected_modulefile"
    # Catch stale-template and wrong-spec outputs before variant generation.
    if grep -Eq '\{\{|\{%' "$expected_modulefile"; then
        die "Source module contains unrendered template expressions: $expected_modulefile"
    fi
    grep -Fq "$real_package_prefix_dir/bin" "$expected_modulefile" ||
        die "Source module does not reference the installed binary: $expected_modulefile"
done

printf 'Generating requested variants from rendered base modules...\n'

# ------------------------------------------------------------------------------
# Step 5: generate requested custom variants and stage the shared BASH_ENV compatibility patch files.
# ------------------------------------------------------------------------------
# Prepare the variant staging directory, collect the rendered base modulefiles,
# and initialize the artifact tracking arrays and generation log.
variant_dir="$stage_dir/$variant_module_relative_dir"
mkdir -p "$variant_dir"
shopt -s nullglob
base_modulefiles_arr=("$rendered_dir/$source_module_relative_dir/"*.lua)
[ "${#base_modulefiles_arr[@]}" -gt 0 ] || die "Spack rendered no installed base modules."
declare -a candidates_arr=() target_relatives_arr=() generated_module_names_arr=()
variant_generation_log="$run_dir/variant-generation.log"
: > "$variant_generation_log"

# Generate each requested flavour from every rendered base module, normalize its
# provenance header, and record the staged candidate and publication metadata.
for base_modulefile in "${base_modulefiles_arr[@]}"; do
    module_version=${base_modulefile##*/}
    module_version=${module_version%.lua}
    for flavour in "${flavours_arr[@]}"; do
        variant_args_arr=(
            --input-dir "$rendered_dir/$source_module_relative_dir"
            --output-dir "$variant_dir"
            --version "$module_version" --flavour "$flavour"
        )
        [ -z "$suffix" ] || variant_args_arr+=(--suffix "$suffix")
        modulefile_name="$module_version-$flavour${suffix:+-$suffix}.lua"
        printf 'Generate module_version=%s flavour=%s output=%s\n' \
            "$module_version" "$flavour" "$variant_dir/$modulefile_name" >> "$variant_generation_log"
        "$creator_script" "${variant_args_arr[@]}" >> "$variant_generation_log" 2>&1 ||
            die "Variant generation failed; see $variant_generation_log"

        # Keep stable provenance without a generation timestamp.
        sed -i \
            -e '/^-- Module file created by spack /s/ on .*//' \
            -e '/^-- Module file created by spack /a\
-- Customized by PawseySC/pawsey-spack-config:\
--   scripts/generate_singularity_modules.sh (driver)\
--   scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh (flavour transformations)' \
            "$variant_dir/$modulefile_name"

        candidates_arr+=("$variant_dir/$modulefile_name")
        target_relatives_arr+=("$variant_module_relative_dir/$modulefile_name")
        module_name="$singularity_name/${modulefile_name%.lua}"
        generated_module_names_arr+=("$module_name")
    done
done

# Report module candidates before shared patch files join the candidate list.
printf 'Generated staged module candidates under:\n'
printf '  %s\n' "$variant_dir"
printf 'Staged module candidates:\n'
for index in "${!generated_module_names_arr[@]}"; do
    printf '  %s -> %s\n' \
        "${generated_module_names_arr[$index]}" "${candidates_arr[$index]##*/}"
done

# Stage the shared BASH_ENV compatibility patch files and register them as
# validation and publication candidates.
bash_env_patch_dir="$stage_dir/pawsey/lmod-variable-fixes"
mkdir -p "$bash_env_patch_dir"
for bash_env_patch_file in pawsey_fix_initial_bash.lua pawsey_init_bash; do
    cp -p -- "$PAWSEY_SPACK_CONFIG_REPO/scripts/$bash_env_patch_file" "$bash_env_patch_dir/$bash_env_patch_file"
    candidates_arr+=("$bash_env_patch_dir/$bash_env_patch_file")
    target_relatives_arr+=("pawsey/lmod-variable-fixes/$bash_env_patch_file")
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
variant_module_root_dir=$(dirname "$variant_dir")
validation_dir=$variant_dir
if [ ! -r "$stack_dir/pawsey/lmod-variable-fixes/pawsey_fix_initial_bash.lua" ] ||
    [ ! -r "$stack_dir/pawsey/lmod-variable-fixes/pawsey_init_bash" ]; then
    # A fresh stack cannot evaluate the template's patch path until publication.
    # Only disposable validation copies use staged patches; candidates stay intact.
    validation_dir="$run_dir/validation/$singularity_name"
    mkdir -p "$validation_dir"
    cp -- "$variant_dir/"*.lua "$validation_dir/"
    sed -i \
        "s|^local patch_dir = .*|local patch_dir = \"$bash_env_patch_dir\"|" \
        "$validation_dir/"*.lua
    printf 'Installed BASH_ENV compatibility patches are missing or unreadable.\n'
    printf 'Lmod checks will use disposable copies with staged patches: %s\n' "$validation_dir"
    printf 'Deliverable modulefiles are unchanged; loading them requires patches at: %s\n' \
        "$stack_dir/pawsey/lmod-variable-fixes"
fi

# Validate every staged candidate with the parser appropriate to its file type.
# Generated modulefiles also undergo Lmod resolution and evaluation checks to
# confirm that Lmod selects and successfully evaluates the intended staged file.
for index in "${!candidates_arr[@]}"; do
    candidate=${candidates_arr[$index]}
    [ -s "$candidate" ] || die "Empty generated candidate: $candidate"
    if [[ "$candidate" == "$variant_dir/"* ]]; then
        luac -p "$candidate"
        module_name="$singularity_name/${candidate##*/}"
        module_name=${module_name%.lua}
        validation_candidate="$validation_dir/${candidate##*/}"
        (
            # This subshell is in an OR-list, where Bash disables errexit.
            module unload "$singularity_name" || exit 1
            module use "$(dirname "$validation_dir")" || exit 1
            selected_modulefile=$(module --ignore-cache --redirect --location show "$module_name") || exit 1
            [ "$selected_modulefile" = "$validation_candidate" ] || {
                printf 'Lmod selected a non-staged module: %s\n' "$selected_modulefile" >&2
                exit 1
            }
            module --ignore-cache --redirect show "$module_name"
        ) > "$run_dir/${candidate##*/}.show.log" 2>&1 ||
            die "Lmod validation failed; see $run_dir/${candidate##*/}.show.log"
    elif [[ "$candidate" == "$bash_env_patch_dir/"*.lua ]]; then
        luac -p "$candidate"
    else
        bash -n "$candidate"
    fi
done

bash_env_patch_file_count=2
variant_count=$((${#candidates_arr[@]} - bash_env_patch_file_count))
printf 'Validated staged artifacts:\n'
printf '  Custom module candidates: %s\n' "$variant_count"
printf '  BASH_ENV compatibility patch files: %s\n' "$bash_env_patch_file_count"

# For testing installations, report the validated staged artifacts and example
# module commands, retain the complete run for inspection, and exit without
# publishing any files to the installed stack.
if [ "$install_type" = testing ]; then
    # Testing is intentionally side-effect free on the installed stack.
    printf 'Generated variants directory: %s\n' "$variant_dir"
    printf 'Generated BASH_ENV compatibility patch directory: %s\n' "$bash_env_patch_dir"
    printf 'Generated module names:\n'
    for module_name in "${generated_module_names_arr[@]}"; do
        printf '  %s\n' "$module_name"
    done
    if [ "${#generated_module_names_arr[@]}" -gt 0 ]; then
        printf 'Example staged usage:\n'
        printf '  module use %q\n' "$variant_module_root_dir"
        printf '  module load %q\n' "${generated_module_names_arr[0]}"
        printf '  module --ignore-cache show %q\n' "${generated_module_names_arr[0]}"
    fi
    printf 'Next actions:\n'
    printf '  1) Inspect staged modules under: %s\n' "$variant_dir"
    printf '  2) Load from staging with the example commands above.\n'
    printf '  3) After functional testing, copy the modulefiles unchanged to: %s\n' \
        "$stack_dir/$variant_module_relative_dir"
    printf '     Alternatively, re-run with --install-type official.\n'
    printf 'Required installed BASH_ENV compatibility patches: %s\n' \
        "$stack_dir/pawsey/lmod-variable-fixes"
    printf 'Logs:\n  %s\n  %s\n' "$run_dir/spack-refresh.log" "$variant_generation_log"
    printf 'Testing output retained without publishing: %s\n' "$run_dir"
    exit 0
fi

# ------------------------------------------------------------------------------
# Step 7: publish officially with lock, preflight, and atomic per-file writes.
# ------------------------------------------------------------------------------
# Use flock to acquire an exclusive lock and serialize official publication,
# ensuring that only one process modifies the stack at a time.
command -v flock >/dev/null 2>&1 || die "flock is required for safe publication."
lock_file="$stack_dir/.singularity-module-update.lock"
[ ! -L "$lock_file" ] || die "Refusing a symlink lock path: $lock_file"
exec 9>>"$lock_file"
flock -x 9

# Function for validating a relative publication path and safely creating its
# parent directories under the stack prefix without following symlinks.
ensure_safe_parent() {
    local target_relative=$1 current_dir=$stack_dir component
    local -a components_arr
    [[ "$target_relative" =~ ^[A-Za-z0-9._/-]+$ && ! "$target_relative" =~ (^|/)\.\.?(/|$) ]] ||
        die "Unsafe target path: $target_relative"
    IFS=/ read -r -a components_arr <<< "${target_relative%/*}"
    for component in "${components_arr[@]}"; do
        [ -n "$component" ] || continue
        current_dir="$current_dir/$component"
        # Reject symlinks at every level; otherwise a seemingly in-stack target
        # could redirect publication to an unrelated tree.
        [ ! -L "$current_dir" ] || die "Refusing symlink target directory: $current_dir"
        if [ -e "$current_dir" ]; then
            [ -d "$current_dir" ] || die "Target parent is not a directory: $current_dir"
        else
            mkdir -- "$current_dir"
            if [ -L "$current_dir" ] || [ ! -d "$current_dir" ]; then
                die "Target directory changed during creation: $current_dir"
            fi
        fi
    done
}

# Build a complete publication plan before changing any destination file. Record
# whether each target is identical, missing, or conflicting with its candidate.
declare -a conflicts_arr=() bash_env_patch_conflicts_arr=() target_paths_arr=() planned_states_arr=()
for index in "${!candidates_arr[@]}"; do
    candidate=${candidates_arr[$index]}
    target_relative=${target_relatives_arr[$index]}
    ensure_safe_parent "$target_relative"
    target="$stack_dir/$target_relative"
    [ ! -L "$target" ] || die "Refusing symlink destination: $target"
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "Destination is not a regular file: $target"
        if cmp -s -- "$candidate" "$target"; then
            planned_states_arr+=(identical)
        else
            conflicts_arr+=("$target")
            [[ "$target_relative" == pawsey/lmod-variable-fixes/* ]] &&
                bash_env_patch_conflicts_arr+=("$target")
            planned_states_arr+=(conflict)
        fi
    else
        planned_states_arr+=(missing)
    fi
    target_paths_arr+=("$target")
done
# Report every planned action before enforcing conflicts or modifying the stack.
printf 'Publication plan:\n'
for index in "${!candidates_arr[@]}"; do
    case "${planned_states_arr[$index]}" in
        identical) printf '  reuse     %s\n' "${target_paths_arr[$index]}" ;;
        missing) printf '  create    %s\n' "${target_paths_arr[$index]}" ;;
        conflict) printf '  conflict  %s\n' "${target_paths_arr[$index]}" ;;
    esac
done
# Stop before publication if any existing destination differs from its staged
# candidate and --force was not specified.
if [ "${#conflicts_arr[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
    printf 'ERROR: Differing destinations were found; no files were published:\n' >&2
    printf '  %s\n' "${conflicts_arr[@]}" >&2
    if [ "${#bash_env_patch_conflicts_arr[@]}" -gt 0 ]; then
        printf 'A shared BASH_ENV compatibility patch conflict affects every generated module.\n' >&2
    fi
    die "Use --force only for an official installation to replace these files."
fi
# Warn before force-replacing shared BASH_ENV compatibility patch files because
# the change may affect installed Singularity modules outside the current update.
if [ "${#bash_env_patch_conflicts_arr[@]}" -gt 0 ]; then
    printf 'WARNING: This forced publication will replace shared BASH_ENV compatibility patch files.\n' >&2
    printf 'The change may affect every installed Singularity module that uses these files, not only the modules updated by this run:\n' >&2
    printf '  %s\n' "${bash_env_patch_conflicts_arr[@]}" >&2
fi

# Publish each validated file safely, one at a time. Each destination changes
# from the complete old file to the complete new file without exposing a partial
# copy. If a later publication fails, files published earlier remain changed.
publication_started=1
printf 'Publishing validated variants and BASH_ENV compatibility patch files into the official tree...\n'
for index in "${!candidates_arr[@]}"; do
    candidate=${candidates_arr[$index]}
    target=${target_paths_arr[$index]}
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
    publication_temp_file=$(mktemp "${target%/*}/.${target##*/}.publish.XXXXXXXX") ||
        die "Could not allocate a publication file beside $target."
    cp -p -- "$candidate" "$publication_temp_file"
    if [ "$state" = replaced ]; then
        if mv -fT -- "$publication_temp_file" "$target"; then
            published_replaced_arr+=("$target")
            publication_temp_file=""
            printf 'Replaced: %s\n' "$target"
        else
            die "Could not atomically replace: $target"
        fi
    else
        # A hard link creates a previously absent target without overwriting a
        # file that raced into place after preflight.
        if ln -T -- "$publication_temp_file" "$target"; then
            rm -f -- "$publication_temp_file"
            publication_temp_file=""
            published_created_arr+=("$target")
            printf 'Created: %s\n' "$target"
        else
            rm -f -- "$publication_temp_file"
            publication_temp_file=""
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
    "${#published_created_arr[@]}" "${#published_replaced_arr[@]}" \
    "$((${#candidates_arr[@]} - ${#published_created_arr[@]} - ${#published_replaced_arr[@]}))"
printf 'Published variants directory: %s\n' "$stack_dir/$variant_module_relative_dir"
printf 'Published BASH_ENV compatibility patch directory: %s\n' "$stack_dir/pawsey/lmod-variable-fixes"
printf 'Published module names:\n'
for module_name in "${generated_module_names_arr[@]}"; do
    printf '  %s\n' "$module_name"
done
if [ "${#generated_module_names_arr[@]}" -gt 0 ]; then
    printf 'Next actions:\n'
    printf '  1) module use %q\n' "$(dirname "$stack_dir/$variant_module_relative_dir")"
    printf '  2) module load %q\n' "${generated_module_names_arr[0]}"
    printf '  3) module --ignore-cache show %q\n' "${generated_module_names_arr[0]}"
fi
printf 'Logs:\n  %s\n  %s\n' "$run_dir/spack-refresh.log" "$variant_generation_log"
printf 'Staging and validation logs retained at: %s\n' "$run_dir"
