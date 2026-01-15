#!/bin/bash 

# ============================================================================
# Environment validation
# ============================================================================

function check_settings()
{
    local missing=""
    
    if [[ -z "${DATE_TAG+x}" ]]; then
        missing+="  DATE_TAG\n"
    fi
    if [[ -z "${INSTALL_PREFIX+x}" ]]; then
        missing+="  INSTALL_PREFIX\n"
    fi
    if [[ -z "${gcc_version+x}" ]]; then
        missing+="  gcc_version\n"
    fi
    if [[ -z "${nvidia_version+x}" ]]; then
        missing+="  nvidia_version\n"
    fi
    
    if [[ -n "$missing" ]]; then
        echo "Error: Required environment variables are not set."
        echo "Missing variables:"
        echo -e "$missing"
        echo "Please source settings.sh before running this script:"
        echo "  source /path/to/systems/setonix-q/settings.sh"
        exit 1
    fi
}

# ============================================================================
# Argument parsing helpers
# ============================================================================

function show_usage()
{
    echo "Usage: $0 [OPTIONS]"
    echo "  --module-only  Skip software installation, only create/update module file"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  source /path/to/systems/setonix-q/settings.sh"
    exit 0
}

function parse_args()
{
    # Save starting directory for restoration at end
    export _UTILS_START_DIR="$PWD"
    
    export MODULE_ONLY=false
    for arg in "$@"; do
        case $arg in
            --module-only)
                MODULE_ONLY=true
                ;;
            -h|--help)
                show_usage
                ;;
        esac
    done
    
    # Validate environment after parsing args
    check_settings
}

function should_install_software()
{
    [[ "$MODULE_ONLY" != "true" ]]
}

# ============================================================================
# Build helpers
# ============================================================================

function setup_build_dir()
{
    build_dir="$MYSCRATCH/${tool_name}-build"
    mkdir -p ${build_dir}
    cd ${build_dir}
    echo "Build directory: ${build_dir}"
}

function download_archive()
{
    local archive=$1
    local url=$2
    
    if [[ ! -f "${archive}" ]]; then
        echo "Downloading ${tool_name} ${tool_ver}..."
        wget -q "${url}" || { echo "Error: Download failed from ${url}"; exit 1; }
    else
        echo "Archive already present: ${archive}"
        # Verify the archive is valid
        if ! xz -t "${archive}" 2>/dev/null && ! gzip -t "${archive}" 2>/dev/null; then
            echo "Warning: Existing archive may be corrupt, re-downloading..."
            rm -f "${archive}"
            wget -q "${url}" || { echo "Error: Download failed from ${url}"; exit 1; }
        fi
    fi
}

function extract_archive()
{
    local archive=$1
    echo "Extracting ${archive}..."
    
    if [[ "${archive}" == *.tar.xz ]]; then
        tar -xf "${archive}" || { echo "Error: Failed to extract ${archive}"; exit 1; }
    elif [[ "${archive}" == *.tar.gz ]]; then
        tar -xzf "${archive}" || { echo "Error: Failed to extract ${archive}"; exit 1; }
    elif [[ "${archive}" == *.tar.bz2 ]]; then
        tar -xjf "${archive}" || { echo "Error: Failed to extract ${archive}"; exit 1; }
    else
        echo "Error: Unknown archive format"
        exit 1
    fi
}

function install_files()
{
    local source_dir=$1
    if [[ ! -d "${source_dir}" ]]; then
        echo "Error: Source directory ${source_dir} does not exist"
        exit 1
    fi
    echo "Installing to ${install_dir}..."
    mkdir -p "${install_dir}"
    cp -r ${source_dir}/* "${install_dir}/"
    set_permissions "${install_dir}"
}

function set_permissions()
{
    local target_dir=$1
    if [[ -d "${target_dir}" ]]; then
        echo "Setting permissions on ${target_dir}..."
        # Match Spack packages.yaml policy: read=world, write=user
        chmod -R u+rwX,go+rX,go-w "${target_dir}"
    fi
}

function cleanup_build()
{
    echo "Cleaning up build directory..."
    rm -rf ${build_dir}
}

function finalize_install()
{
    local template=${1:-module.lua}
    
    # Set permissions on install directory (for pip-installed packages)
    # install_files already calls this, but pip installs don't use install_files
    if [[ -d "${install_dir}" ]]; then
        set_permissions "${install_dir}"
    fi
    
    install_module ${install_dir} ${tool_name} ${tool_ver} "${brief}" "${descrip}" "${template}"
    echo "${tool_name} ${tool_ver} installation complete!"
    
    # Restore starting directory
    if [[ -n "${_UTILS_START_DIR}" ]]; then
        cd "${_UTILS_START_DIR}"
    fi
}

# ============================================================================
# Module installation
# ============================================================================

function install_module()
{
    local INSTALL_DIR=$1
    local NAME=$2
    local VERSION=$3
    local BRIEF=$4
    local DESCRIP=$5
    local TEMPLATE=${6:-sample.lua}  # Optional template, defaults to sample.lua

    echo "Creating module: ${MODULE_DIR}/${NAME}/${VERSION}.lua"
    mkdir -p ${MODULE_DIR}/${NAME}/
    local modname=${MODULE_DIR}/${NAME}/${VERSION}.lua
    
    # Look for template in script_dir first, then parent directory
    if [[ -f "${script_dir}/${TEMPLATE}" ]]; then
        cp ${script_dir}/${TEMPLATE} ${modname}
    elif [[ -f "${script_dir}/../${TEMPLATE}" ]]; then
        cp ${script_dir}/../${TEMPLATE} ${modname}
    else
        echo "Error: Template ${TEMPLATE} not found in ${script_dir} or parent"
        return 1
    fi

    # update lua module
    # NOTE: Order matters! Longer patterns first to avoid partial matches
    # (e.g., COMPILER_VERSION before VERSION, INSTALL_PATH before PATH)
    local build_date=$(date +%Y-%m-%d)
    local compiler_ver="${nvhpc_ver:-unknown}"
    
    sed -i "s:COMPILER_VERSION:nvhpc@${compiler_ver}:g" ${modname}
    sed -i "s:INSTALL_PATH:${INSTALL_DIR}:g" ${modname}
    sed -i "s:BUILD_DATE:${build_date}:g" ${modname}
    sed -i "s:VERSION:${VERSION}:g" ${modname}
    sed -i "s:DESCRIP:${DESCRIP}:g" ${modname}
    sed -i "s:BRIEF:${BRIEF}:g" ${modname}
    sed -i "s:NAME:${NAME}:g" ${modname}

    # add the dependencies
    local dstring=""
    for d in ${dependencies[@]}
    do
        dstring+="load(\"${d}\")\n"
    done

    sed -i "s:-- dependencies:${dstring}:g" ${modname}
    
    # Set permissions on module file and directory
    set_permissions "${MODULE_DIR}/${NAME}"
}

# ============================================================================
# Dependency management
# ============================================================================

function set_dependencies()
{
    # Ensure a consistent environment for each installation
    module purge
    module load pawsey pawseytools "pawseyenv/${DATE_TAG}"
    module load PrgEnv-gnu-nvidia

    for d in ${dependencies[@]}
    do
        module load ${d}
    done
}