#!/bin/bash
# Test the official OpenFOAM container installation in a private scratch tree.
#
# This is a test driver, not another installer: it calls the existing
# install_shpc_containers.sh once per selected image, then checks the resulting
# modules, SIF links, alias wrappers and `blockMesh -help`. A failed image is
# reported without preventing tests of the remaining images.
#
# Images come from systems/setonix/settings.sh. Recipes come either from the
# official pinned registry or from --repository (including uncommitted edits).
# The installed shpc module is reused; nothing is installed with pip. A private
# HOME keeps SHPC configuration away from your real home and software space.
# Run through submit_shpc_openfoam_test_job.slm or in an interactive allocation.

# =============================================================================
# 1. Command-line options and small reporting helpers
# =============================================================================
# Deliberately do not enable errexit: per-image failures must not end the run.
# Setup operations instead check their status explicitly and stop on failure.
set -o pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'USAGE'
Usage: test_install_shpc_openfoam.sh [OPTIONS]

  --repository DIR       Use this local shpc-registry checkout as-is.
                         Default: clone the official registry at its settings.sh pin.
  --image IMAGE          Test one exact repository:tag from container_list_mpi.
                         Default: all OpenFOAM entries in that official list.
  --date-tag TAG         Existing pawseyenv release, e.g. 2026.09.
                         Default: DATE_TAG, then PAWSEY_STACK_VERSION.
  --prefix DIR           Test tree under MYSCRATCH, ending in /<date-tag>.
                         Default: $MYSCRATCH/openfoam-shpc-tests/<date-tag>.
  --fresh                Remove a marked test tree, including reports, and start again.
  --reinstall            Remove selected images' test artifacts before reinstalling.
  --uninstall            Remove the entire marked test tree and exit (no modules needed).
  --test-timeout SECONDS Timeout for each blockMesh smoke test; default: 60.
  -h, --help             Show this help.

Example:
  bash scripts/test_install_shpc_openfoam.sh --date-tag 2026.09 \
    --repository "$MYSCRATCH/shpc-registry" \
    --image quay.io/pawsey/openfoam-org:14-gcc13DPInt32Opt-mpich4.2.2-ubuntu24.04

Reports are stored in <prefix>/reports/<run-id>/ (CSV summaries and image logs).
Exit status is nonzero if any selected image fails. Never run this with sudo.
USAGE
}

repository=""
image_selection=""
prefix=""
date_tag=${DATE_TAG:-${PAWSEY_STACK_VERSION:-}}
fresh=0; reinstall=0; uninstall=0
test_timeout=60
while [ "$#" -gt 0 ]; do
    case "$1" in
        --repository|--image|--prefix|--date-tag|--test-timeout)
            [ "$#" -ge 2 ] && [ -n "$2" ] || die "Missing value for $1"
            case "$1" in
                --repository) repository=$2 ;;
                --image) image_selection=$2 ;;
                --prefix) prefix=$2 ;;
                --date-tag) date_tag=$2 ;;
                --test-timeout) test_timeout=$2 ;;
            esac
            shift 2 ;;
        --fresh) fresh=1; shift ;;
        --reinstall) reinstall=1; shift ;;
        --uninstall) uninstall=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help)" ;;
    esac
done

# CSV quoting also handles commas and quotes in diagnostic paths.
csv_row() {
    local field separator=""
    for field in "$@"; do
        printf '%s"%s"' "$separator" "${field//\"/\"\"}"
        separator=,
    done
    printf '\n'
}

# =============================================================================
# 2. Validate and protect the test tree before creating or deleting anything
# =============================================================================
[[ "$date_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Supply a valid --date-tag."
[[ "$test_timeout" =~ ^[1-9][0-9]*$ ]] || die "--test-timeout must be positive."
[ "$uninstall" -eq 0 ] || [ "$((fresh + reinstall))" -eq 0 ] || die "--uninstall cannot be combined with --fresh/--reinstall."
[ -n "${MYSCRATCH:-}" ] && [ -d "$MYSCRATCH" ] || die "MYSCRATCH must name an existing scratch directory."
scratch=$(realpath "$MYSCRATCH") || die "Cannot resolve MYSCRATCH."
prefix=${prefix:-$scratch/openfoam-shpc-tests/$date_tag}
prefix=$(realpath -m "$prefix") || die "Cannot resolve the test prefix."

# Official scripts contain unquoted path expansions. Reject unsafe characters
# instead of allowing word splitting or shell/YAML interpretation downstream.
[[ "$prefix" =~ ^/[A-Za-z0-9_./-]+$ ]] || die "The prefix must contain only letters, digits, /, _, ., and -."
case "$prefix" in /software/setonix|/software/setonix/*|/software/projects|/software/projects/*) die "Refusing a software installation prefix." ;; esac
[[ "$prefix" == "$scratch/"* && "$prefix" != "$scratch" && "${prefix##*/}" == "$date_tag" ]] || die "The prefix must be below MYSCRATCH and end in /$date_tag."
[ "$prefix" != "$(realpath "$HOME")" ] || die "The test prefix cannot be your real HOME."

# A supplied registry is read-only input, never part of the disposable tree.
if [ -n "$repository" ]; then
    repository=$(realpath -e "$repository") || die "Registry directory does not exist."
    [[ "$repository" =~ ^/[A-Za-z0-9_./-]+$ ]] || die "Unsupported characters in the registry path."
    [[ "$repository" != "$prefix" && "$repository" != "$prefix/"* ]] || die "Keep the supplied registry outside the disposable test tree."
    git -C "$repository" rev-parse --show-toplevel >/dev/null 2>&1 || die "--repository must be a Git checkout."
fi

# Keep the lock outside the removable tree, so cleanup cannot invalidate it.
mkdir -p "$(dirname "$prefix")" || die "Cannot create the test parent directory."
exec 9>"${prefix}.lock" || die "Cannot open the test lock."
flock -n 9 || die "Another test is using $prefix."
marker="$prefix/.shpc-install-test"
marker_text="OpenFOAM SHPC test; uid=$(id -u); prefix=$prefix"
if [ -e "$prefix" ]; then
    [ -d "$prefix" ] && [ -O "$prefix" ] && [ -f "$marker" ] && [ ! -L "$marker" ] &&
        [ "$(cat "$marker")" = "$marker_text" ] || die "Refusing an unmarked or foreign test tree: $prefix"
    if [ "$fresh" -eq 1 ] || [ "$uninstall" -eq 1 ]; then
        rm -rf -- "$prefix" || die "Could not remove the marked test tree."
    fi
fi
if [ "$uninstall" -eq 1 ]; then
    printf 'Test tree removed (or already absent): %s\n' "$prefix"
    exit 0
fi
mkdir -p "$prefix" || die "Cannot create test tree."
printf '%s\n' "$marker_text" > "$marker" || die "Cannot mark test tree."

# Refuse redirected writable subtrees when reusing a previous test installation.
for directory in test-home containers cache tmp reports registry user-software user-projects pawsey staff_modulefiles; do
    resolved=$(realpath -m "$prefix/$directory") || die "Cannot resolve $directory."
    [[ "$resolved" == "$prefix/"* ]] || die "Writable directory escapes sandbox: $directory"
done
# Reject nested symlinks to outside paths too; generated SHPC links stay inside.
while IFS= read -r -d '' link; do
    resolved=$(realpath -m "$link") || die "Cannot resolve link: $link"
    [[ "$resolved" == "$prefix/"* ]] || die "Symlink escapes sandbox: $link"
done < <(find "$prefix" -type l -print0)

# =============================================================================
# 3. Read official settings, then export only sandbox installation choices
# =============================================================================
PAWSEY_SPACK_CONFIG_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd) || die "Cannot locate repository."
export SYSTEM=setonix DATE_TAG="$date_tag" INSTALL_PREFIX="$prefix"
export INSTALL_GROUP="$(id -gn)"
export HOME="$prefix/test-home" MYSOFTWARE="$prefix/user-software"
export SINGULARITY_CACHEDIR="$prefix/cache" SINGULARITY_TMPDIR="$prefix/tmp" TMPDIR="$prefix/tmp"
mkdir -p "$HOME/.singularity-hpc" "$MYSOFTWARE" "$SINGULARITY_CACHEDIR" "$TMPDIR" "$prefix/staff_modulefiles" || die "Cannot create sandbox directories."
# pawseyenv reads this small project selector from HOME even on module unload.
# Recreate it from the current project, without copying any real home settings.
[[ "${PAWSEY_PROJECT:-}" =~ ^[A-Za-z0-9_-]+$ ]] || die "PAWSEY_PROJECT must identify your current project."
printf '%s\n' "$PAWSEY_PROJECT" > "$HOME/.pawsey_project" || die "Cannot write sandbox project selector."

# Export the include guard and scalar settings so child scripts do not re-read
# settings.sh and restore the production paths or the complete container list.
unset __PSC_SETTINGS__
set -a
. "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/settings.sh" || die "Cannot read official settings."
set +a
export INSTALL_GROUP="$(id -gn)" USER_PERMANENT_FILES_PREFIX="$prefix/user-projects"

# Selection is restricted to the two official OpenFOAM repositories.
images=()
for image in $container_list_mpi; do
    case "$image" in
        quay.io/pawsey/openfoam:*|quay.io/pawsey/openfoam-org:*)
            [ -z "$image_selection" ] || [ "$image" = "$image_selection" ] || continue
            images+=("$image") ;;
    esac
done
[ "${#images[@]}" -gt 0 ] || die "No matching OpenFOAM images in settings.sh. Use an exact repository:tag for --image."
export container_list="" container_list_mpi=""

# Every run gets its own reports, including registry provenance and dirty state.
mkdir -p "$prefix/reports" || die "Cannot create reports directory."
report_dir=$(mktemp -d "$prefix/reports/$(date +%Y%m%d-%H%M%S)-XXXXXXXX") || die "Cannot create run reports."
results="$report_dir/results.csv"
aliases_report="$report_dir/aliases.csv"
csv_row image preflight install validation result log > "$results"
csv_row image alias result resolved_path > "$aliases_report"
printf 'Test prefix: %s\nReports: %s\n' "$prefix" "$report_dir"

# =============================================================================
# 4. Choose the registry and configure the already-installed SHPC
# =============================================================================
if [ -z "$repository" ]; then
    repository="$prefix/registry"
    # A fresh clone contains only the pinned official recipes. Never checkout or
    # reset a user-supplied repository, including when --reinstall is requested.
    if [ ! -d "$repository/.git" ]; then
        git clone https://github.com/pawseySC/shpc-registry "$repository" > "$report_dir/registry.log" 2>&1 || die "Registry clone failed; see $report_dir/registry.log."
    fi
    git -C "$repository" checkout --detach "$shpc_registry_version" >> "$report_dir/registry.log" 2>&1 || die "Cannot checkout registry pin; see registry.log."
fi
{
    printf 'Registry: %s\nOfficial pin: %s\n' "$repository" "$shpc_registry_version"
    git -C "$repository" rev-parse HEAD
    git -C "$repository" status --short
    printf '\nInstallation repository:\n'
    git -C "$PAWSEY_SPACK_CONFIG_REPO" rev-parse HEAD
    git -C "$PAWSEY_SPACK_CONFIG_REPO" status --short
    printf '\nSelected images:\n%s\n' "${images[@]}"
} > "$report_dir/provenance.txt"

# Loading existing modules is not a Python or pip installation. The official
# container installer also loads its normal dependencies in its child process.
type module >/dev/null 2>&1 || . /usr/share/lmod/lmod/init/bash
module load "pawseyenv/$pawseyenv_version" || die "Unavailable pawseyenv/$pawseyenv_version."
module load "$shpc_name/$shpc_version" || die "Unavailable $shpc_name/$shpc_version."
base_settings="${PAWSEY_SHPC_HOME}/lib/python${python_version_major}.${python_version_minor}/site-packages/shpc/settings.yml"
[ -f "$base_settings" ] || die "Cannot find installed SHPC settings: $base_settings"
settings_file="$HOME/.singularity-hpc/settings.yml"

# Copy first: SHPC config commands must never target its system settings file.
# Change values through SHPC itself, preserving its nested wrapper settings.
cp "$base_settings" "$settings_file" || die "Cannot create private SHPC settings."
configure() { shpc config set "$1" >> "$report_dir/setup.log" 2>&1 || die "SHPC configuration failed: $1 (see setup.log)"; }
# Registry is a YAML list; replace it rather than adding to inherited registries.
sed -i '/^registry:/,/^[^[:space:]#]/ { /^registry:/c\registry: []
    /^[[:space:]]/d
}' "$settings_file" || die "Cannot clear inherited registries."
shpc config add registry "$repository" >> "$report_dir/setup.log" 2>&1 || die "Cannot select test registry."
configure module_sys:lmod
configure container_tech:singularity
configure "module_base:$prefix/$shpc_containers_modules_dir_long"
configure "container_base:$prefix/$shpc_containers_dir"
configure "wrapper_base:$prefix/containers/wrappers"
configure "views_base:$prefix/${shpc_containers_modules_dir%/*}"
configure "default_view:${shpc_containers_modules_dir##*/}"
configure default_version:null
configure "singularity_module:$singularity_name/$singularity_version"
configure wrapper_scripts:enabled:true
configure container_features:x11:true
configure "container_features:home:$prefix/container-home"
mkdir -p "$prefix/container-home" || die "Cannot create container home."
view_dir="$prefix/$shpc_containers_modules_dir"
if [ ! -f "$view_dir/view.yaml" ]; then
    shpc view create "${shpc_containers_modules_dir##*/}" >> "$report_dir/setup.log" 2>&1 || die "Cannot create SHPC view."
fi

# =============================================================================
# 5. Per-image preflight and optional removal of selected test artifacts
# =============================================================================
# These recipes use simple two-space YAML mappings. Read exactly the requested
# section/key, including quoted numeric-looking tags; do not match substrings.
mapping_value() {
    awk -v section="$2" -v wanted="$3" '
        function unquote(s) { gsub(/^[\047\042]|[\047\042]$/, "", s); return s }
        /^[^ #]/ { inside=($0 == section ":"); next }
        inside && /^  [^ #]/ {
            colon=index($0, ":"); if (!colon) next
            key=substr($0, 3, colon-3)
            if (unquote(key) != wanted) next
            value=substr($0, colon+1)
            sub(/[[:space:]]+#.*/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print unquote(value)
        }
    ' "$1"
}

preflight() {
    local image=$1 recipe tag alias_rel alias_file
    recipe="$repository/${image%:*}/container.yaml"
    tag=${image##*:}
    [ -f "$recipe" ] || { echo "Missing recipe: $recipe"; return 1; }
    [ -n "$(mapping_value "$recipe" tags "$tag")" ] || { echo "Missing tag: $image"; return 1; }
    alias_rel=$(mapping_value "$recipe" overrides "$tag")
    [ -n "$alias_rel" ] || { echo "Missing alias override: $image"; return 1; }
    alias_file=$(realpath -m "${recipe%/*}/$alias_rel") || return 1
    [[ "$alias_file" == "$repository/"* ]] && [ -f "$alias_file" ] || { echo "Missing or external alias file: $alias_file"; return 1; }
    # Save a per-run alias list: later registry edits cannot change expectations.
    awk '/^aliases:$/ {inside=1; next} /^[^ #]/ {inside=0}
        inside && /^  [^ #][^:]*:/ {name=$1; sub(/:$/, "", name); print name}' "$alias_file" > "$alias_list"
    [ -s "$alias_list" ] || { echo "No aliases declared: $alias_file"; return 1; }
    # Require the smoke-test command to belong to this image, not another module
    # that happens to supply blockMesh on the inherited PATH.
    grep -Fxq blockMesh "$alias_list" || { echo "Missing blockMesh alias: $alias_file"; return 1; }
    sha256sum "$recipe" "$alias_file"
}

remove_image() {
    local image=$1 tool=${1%:*} tag=${1##*:} link target
    tool=${tool##*/}
    target="$prefix/$shpc_containers_modules_dir_long/${image%:*}/$tag/module.lua"
    # Remove only view links that point at this image, including shortened names.
    for link in "$view_dir/$tool"/*.lua "$view_dir/$tool$shpc_spackuser_container_tag"/*.lua; do
        [ -L "$link" ] || continue
        [ "$(readlink -f "$link")" != "$target" ] || rm -- "$link" || return 1
    done
    rm -rf -- "${target%/module.lua}" "$prefix/$shpc_containers_dir/${image%:*}/$tag" \
        "$prefix/containers/wrappers/${image%:*}/$tag" || return 1
    rm -f -- "$prefix/$containers_root_dir/openfoam-sif/${tool}_${tag}.sif"
}

# =============================================================================
# 6. Invoke the real installer, continuing after each failed image
# =============================================================================
declare -A preflight_status install_status image_logs alias_lists
for image in "${images[@]}"; do
    tag=${image##*:}; tool=${image%:*}; tool=${tool##*/}
    log="$report_dir/${tool}_${tag}.log"
    alias_list="$report_dir/${tool}_${tag}.aliases.txt"
    image_logs[$image]=$log; alias_lists[$image]=$alias_list
    preflight_status[$image]=FAIL; install_status[$image]=SKIP
    printf 'Checking %s\n' "$image"
    if ! preflight "$image" > "$log" 2>&1; then
        printf '  FAIL: preflight; see %s\n' "$log"
        continue
    fi
    preflight_status[$image]=PASS
    install_status[$image]=FAIL
    if [ "$reinstall" -eq 1 ] && ! remove_image "$image" >> "$log" 2>&1; then
        printf '  FAIL: cannot remove selected artifacts; see %s\n' "$log"
        continue
    fi
    export container_list_mpi="$image"
    # Run a separate Bash with the official errexit behavior. Do not inherit
    # pipefail: the installer's `yes | shpc` legitimately gives yes a SIGPIPE.
    if env -u SHELLOPTS bash -e "$PAWSEY_SPACK_CONFIG_REPO/scripts/install_shpc_containers.sh" >> "$log" 2>&1; then
        # Reproduce the second patch call from post_installation_operations.sh,
        # without running that script's unrelated system-wide operations.
        if env -u SHELLOPTS bash -e "$PAWSEY_SPACK_CONFIG_REPO/scripts/patch_shpc_pawsey_modules.sh" >> "$log" 2>&1; then
            install_status[$image]=PASS
            printf '  Installed; validation follows after all images.\n'
        fi
    fi
    [ "${install_status[$image]}" = PASS ] || printf '  FAIL: installation; see %s\n' "$log"
done

# =============================================================================
# 7. Validate the final shared tree in an isolated shell per image
# =============================================================================
# Validate after all installations: a later collision can legitimately change
# an earlier short view name back to its full tag.
validate_image() (
    image=$1; alias_list=$2
    tag=${image##*:}; tool=${image%:*}; tool=${tool##*/}
    target="$prefix/$shpc_containers_modules_dir_long/${image%:*}/$tag/module.lua"
    [ -f "$target" ] || { echo "Missing long module: $target"; exit 1; }
    grep -Fxq "conflict(\"$tool$shpc_spackuser_container_tag\")" "$target" || { echo "Wrong module conflict."; exit 1; }

    # Compute the expected name independently from all installed long versions.
    count=0
    for installed in "$prefix/$shpc_containers_modules_dir_long/${image%:*}"/*/module.lua; do
        [ -f "$installed" ] || continue
        version=${installed%/module.lua}; version=${version##*/}
        [ "${version%%-*}" != "${tag%%-*}" ] || count=$((count + 1))
    done
    version=$tag
    [ "$count" -ne 1 ] || version=${tag%%-*}
    module_name="$tool$shpc_spackuser_container_tag/$version"
    link="$view_dir/$module_name.lua"
    [ -L "$link" ] && [ "$(readlink -f "$link")" = "$target" ] || { echo "Wrong or missing view link: $link"; exit 1; }

    # Both the SIF and its convenient OpenFOAM link retain the complete tag.
    shopt -s nullglob
    sifs=("$prefix/$shpc_containers_dir/${image%:*}/$tag/"*.sif)
    [ "${#sifs[@]}" -eq 1 ] || { echo "Expected one SIF, found ${#sifs[@]}."; exit 1; }
    sif_link="$prefix/$containers_root_dir/openfoam-sif/${tool}_${tag}.sif"
    [ -L "$sif_link" ] && [ "$(readlink -f "$sif_link")" = "$(realpath "${sifs[0]}")" ] || { echo "Wrong SIF link: $sif_link"; exit 1; }

    # Unload an inherited OpenFOAM module before loading this sandbox module.
    IFS=: read -r -a loaded_modules <<< "${LOADEDMODULES:-}"
    for loaded in "${loaded_modules[@]}"; do
        case "$loaded" in openfoam/*|openfoam-org/*|openfoam-container/*|openfoam-org-container/*) module unload "$loaded" || exit 1 ;; esac
    done
    module unload singularity || exit 1
    module use "$view_dir" || exit 1
    module load "$module_name" || exit 1
    module is-loaded "$singularity_name/$singularity_mpi_version" || { echo "MPI Singularity module not loaded."; exit 1; }
    # A globally installed module with the same name must not yield a false pass.
    found=0
    IFS=: read -r -a loaded_files <<< "${_LMFILES_:-}"
    for loaded in "${loaded_files[@]}"; do
        [ "$(readlink -f "$loaded")" != "$target" ] || found=1
    done
    [ "$found" -eq 1 ] || { echo "Loaded module did not come from sandbox."; exit 1; }

    # Check every declared alias resolves to this image's executable wrapper.
    failures=0
    while IFS= read -r alias; do
        wrapper="$prefix/containers/wrappers/${image%:*}/$tag/bin/$alias"
        resolved=$(command -v "$alias")
        result=FAIL
        if [ -x "$wrapper" ] && [ "$resolved" = "$wrapper" ]; then result=PASS; else failures=$((failures + 1)); fi
        csv_row "$image" "$alias" "$result" "$resolved" >> "$aliases_report"
    done < "$alias_list"
    [ "$failures" -eq 0 ] || { echo "$failures aliases failed."; exit 1; }

    # Check complete output, not a truncated summary, and require exit code zero.
    smoke="$report_dir/${tool}_${tag}.smoke.log"
    timeout "$test_timeout" blockMesh -help > "$smoke" 2>&1
    status=$?
    cat "$smoke"
    [ "$status" -eq 0 ] && grep -Fq 'Usage: blockMesh [OPTIONS]' "$smoke" || { echo "Smoke test failed (exit $status)."; exit 1; }
)

# =============================================================================
# 8. Write the per-image summary and return an honest overall result
# =============================================================================
failures=0
for image in "${images[@]}"; do
    validation=SKIP; result=FAIL
    if [ "${install_status[$image]}" = PASS ]; then
        validation=FAIL
        if validate_image "$image" "${alias_lists[$image]}" >> "${image_logs[$image]}" 2>&1; then
            validation=PASS; result=PASS
        fi
    fi
    [ "$result" = PASS ] || failures=$((failures + 1))
    csv_row "$image" "${preflight_status[$image]}" "${install_status[$image]}" "$validation" "$result" "${image_logs[$image]}" >> "$results"
    printf '%s: %s (preflight=%s install=%s validation=%s)\n' "$result" "$image" "${preflight_status[$image]}" "${install_status[$image]}" "$validation"
done
printf '\nImages: %s; failures: %s\nResults: %s\n' "${#images[@]}" "$failures" "$results"
[ "$failures" -eq 0 ]
