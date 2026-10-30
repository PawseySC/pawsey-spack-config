#!/bin/bash
#
# Shared preparation and generation for installation and module-only updates.
# Callers source settings.sh first. INSTALL_PREFIX always identifies the real
# software stack; the output tree can instead be a private staging directory.
# psc_generate_singularity_modules STACK OUTPUT RUN [VERSION] selects all
# matching installed versions when VERSION is omitted (installation only).

psc_expand_stack_paths() {
    sed -i \
        -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
        -e "s|DATE_TAG|${DATE_TAG}|g" \
        -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g" \
        -e "s|USER_TEMP_FILES_PREFIX|${USER_TEMP_FILES_PREFIX}|g" \
        -e "s|BOOTSTRAP_PATH|${BOOTSTRAP_PATH}|g" \
        "$@"
}

psc_prepare_module_inputs() {
    local templates=$1 site=$2 staff=$3
    mkdir -p "$templates" "$site" "$staff"
    cp -R "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/." "$templates/"
    cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/site/modules.yaml" "$site/"
    cp "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/configs/spackuser/modules.yaml" "$staff/"
    psc_expand_stack_paths \
        "$templates/modules/modulefile.lua" "$site/modules.yaml" "$staff/modules.yaml"
}

psc_singularity_module_paths() {
    : "${cpu_arch:?Missing cpu_arch in settings.sh}" "${gcc_version:?Missing gcc_version in settings.sh}"
    : "${singularity_name_general:?Missing singularity_name_general in settings.sh}"
    : "${singularity_symlink_module_dir:?Missing singularity_symlink_module_dir in settings.sh}"
    source_relative="modules/$cpu_arch/gcc/$gcc_version/utilities/$singularity_name_general"
    variants_relative="$singularity_symlink_module_dir"
}

psc_generate_singularity_modules() {
    set -e -o pipefail
    local stack_prefix=$1 stage=$2 run=$3 version=${4:-}
    local source_relative variants_relative
    local INSTALL_PREFIX=$INSTALL_PREFIX __PSC_SETTINGS__=$__PSC_SETTINGS__
    # Keep an empty local binding: unset would expose an inherited global value.
    local -x PYTHONSTARTUP=""
    local SPACK_DISABLE_LOCAL_CONFIG SPACK_USER_CONFIG_PATH SPACK_USER_CACHE_PATH
    local SPACK_SYSTEM_CONFIG_PATH PYTHONDONTWRITEBYTECODE SPACK_PYTHON
    psc_singularity_module_paths
    local generator="$PAWSEY_SPACK_CONFIG_REPO/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"
    local spack="$stack_prefix/spack/bin/realspack"
    [ -x "$spack" ] || { printf 'ERROR: Installed Spack executable not found: %s\n' "$spack" >&2; exit 1; }
    mkdir -p "$stage/$variants_relative" "$run/overrides" "$run/cache"
    # Prepare the same inputs for both callers; only output/cache paths differ.
    psc_prepare_module_inputs "$run/templates" "$run/site" "$run/staff"
    sha256sum "$generator" \
        "$PAWSEY_SPACK_CONFIG_REPO/scripts/singularity_module_pipeline.sh" \
        "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/templates/modules/modulefile.lua" \
        > "$run/input-checksums"

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

    # Use the recipes already installed with this Spack, without registry fetches.
    local builtin="$stack_prefix/spack/var/spack/repos/builtin/repos/spack_repo/builtin"
    local pawsey="$stack_prefix/spack/var/spack/repos/pawsey"
    [[ -f "$builtin/repo.yaml" && -f "$pawsey/repo.yaml" ]] ||
        { printf 'ERROR: Expected installed Spack 1.1.1 recipe repositories are missing.\n' >&2; exit 1; }
    cat > "$run/overrides/repos.yaml" <<EOF
repos::
  pawsey_repo: '$pawsey'
  builtin: '$builtin'
EOF
    export SPACK_DISABLE_LOCAL_CONFIG=1
    export SPACK_USER_CONFIG_PATH="$run/user-config" SPACK_USER_CACHE_PATH="$run/cache/user"
    export SPACK_SYSTEM_CONFIG_PATH="$run/system-config"
    export PYTHONDONTWRITEBYTECODE=1
    local -a spack_command=("$spack" -E -C "$run/site" -C "$run/staff" -C "$run/overrides")
    type module >/dev/null 2>&1 ||
        { printf 'ERROR: The Lmod module command must be available.\n' >&2; exit 1; }
    module use "$stack_prefix/modules/$cpu_arch/gcc/$gcc_version/programming-languages"
    : "${python_name:?Missing python_name in settings.sh}" "${python_version:?Missing python_version in settings.sh}"
    module load "$python_name/$python_version"
    export SPACK_PYTHON
    SPACK_PYTHON=$(command -v python3) ||
        { printf 'ERROR: The stack Python module did not expose python3.\n' >&2; exit 1; }

    # Resolve installed specs, never concretize or install software.
    local query="$singularity_name_general"
    [ -z "$version" ] || query+="@=$version"
    "${spack_command[@]}" find --format '{hash} {prefix} {compiler.name} {compiler.version}' \
        "$query target=$cpu_arch" > "$run/installed-specs.txt"
    local hash package_prefix compiler compiler_version
    local -a hashes=() prefixes=()
    while read -r hash package_prefix compiler compiler_version; do
        if [ "$compiler" = gcc ] && [ "$compiler_version" = "$gcc_version" ]; then
            hashes+=("$hash")
            prefixes+=("$package_prefix")
        fi
    done < "$run/installed-specs.txt"
    if [ "${#hashes[@]}" -eq 0 ] ||
        { [ -n "$version" ] && [ "${#hashes[@]}" -ne 1 ]; }; then
        printf 'ERROR: Expected installed %s for %s/GCC %s (%s); found %s. See %s/installed-specs.txt\n' \
            "$query" "$cpu_arch" "$gcc_version" \
            "exactly one for a selected version, at least one for installation" "${#hashes[@]}" "$run" >&2
        exit 1
    fi
    printf '%s\n' "${hashes[@]}" > "$run/spec-hash"
    local index resolved source_module filename
    for index in "${!hashes[@]}"; do
        hash=${hashes[$index]}
        package_prefix=${prefixes[$index]}
        [[ "$hash" =~ ^[a-z0-9]+$ && "$package_prefix" == "$stack_prefix/software/"* &&
            -d "$package_prefix" ]] ||
            { printf 'ERROR: Selected spec is not a valid installation inside this stack.\n' >&2; exit 1; }
        printf 'Reusing installed package: %s\n' "$package_prefix"
        resolved=$("${spack_command[@]}" python -c \
            "import spack.store, spack.modules.lmod; spec = spack.store.STORE.db.query('/$hash')[0]; print(spack.modules.lmod.LmodModulefileWriter(spec, 'default').layout.filename)")
        filename=${resolved##*/}
        [[ "${resolved%/*}" = "$stage/$source_relative" &&
            "$filename" =~ ^[0-9]+(\.[0-9]+)*\.lua$ &&
            ( -z "$version" || "$filename" = "$version.lua" ) ]] ||
            { printf 'ERROR: Spack resolved an unexpected output path: %s\n' "$resolved" >&2; exit 1; }
        source_module=$resolved
        "${spack_command[@]}" module lmod refresh -y "/$hash" 2>&1 | tee -a "$run/spack-refresh.log"
        [ -s "$source_module" ] ||
            { printf 'ERROR: Spack did not produce the expected source module.\n' >&2; exit 1; }
        if grep -Eq '\{\{|\{%' "$source_module"; then
            printf 'ERROR: Source module contains unrendered template expressions.\n' >&2
            exit 1
        fi
        grep -Fq "$package_prefix/bin" "$source_module" ||
            { printf 'ERROR: Source module does not reference the installed binary.\n' >&2; exit 1; }
    done
    # Preserve the loaded settings while redirecting only the generator's output.
    export __PSC_SETTINGS__ INSTALL_PREFIX="$stage"
    bash -e "$generator" 2>&1 | tee "$run/variant-generation.log"
}
