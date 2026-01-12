#!/bin/bash 

# ============================================================================
# Argument parsing helpers
# ============================================================================

function show_usage()
{
    echo "Usage: $0 [OPTIONS]"
    echo "  --module-only  Skip software installation, only create/update module file"
    echo "  -h, --help     Show this help message"
    exit 0
}

function parse_args()
{
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
        wget -q "${url}" || { echo "Error: Download failed"; return 1; }
    else
        echo "Archive already present: ${archive}"
    fi
}

function extract_archive()
{
    local archive=$1
    echo "Extracting ${archive}..."
    
    if [[ "${archive}" == *.tar.xz ]]; then
        tar -xf "${archive}"
    elif [[ "${archive}" == *.tar.gz ]]; then
        tar -xzf "${archive}"
    elif [[ "${archive}" == *.tar.bz2 ]]; then
        tar -xjf "${archive}"
    else
        echo "Error: Unknown archive format"
        return 1
    fi
}

function install_files()
{
    local source_dir=$1
    echo "Installing to ${install_dir}..."
    mkdir -p "${install_dir}"
    cp -r ${source_dir}/* "${install_dir}/"
}

function cleanup_build()
{
    echo "Cleaning up build directory..."
    cd ${script_dir}
    rm -rf ${build_dir}
}

function finalize_install()
{
    local template=${1:-module.lua}
    install_module ${install_dir} ${tool_name} ${tool_ver} "${brief}" "${descrip}" "${template}"
    echo "${tool_name} ${tool_ver} installation complete!"
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
    local fields=(INSTALL_PATH NAME VERSION BRIEF DESCRIP COMPILER_VERSION BUILD_DATE)
    local build_date=$(date +%Y-%m-%d)
    local compiler_ver="${nvhpc_ver:-unknown}"
    local values=("${INSTALL_DIR}" "${NAME}" "${VERSION}" "${BRIEF}" "${DESCRIP}" "nvidia@${compiler_ver}" "${build_date}")
    for ((i=0;i<7;i++))
    do
        sed -i "s:${fields[${i}]}:${values[${i}]}:g" ${modname}
    done

    # add the dependencies
    local dstring=""
    for d in ${dependencies[@]}
    do
        dstring+="load(\"${d}\")\n"
    done

    sed -i "s:-- dependencies:${dstring}:g" ${modname}
}

# ============================================================================
# Dependency management
# ============================================================================

function set_dependencies()
{
    for d in ${dependencies[@]}
    do
        module load ${d}
    done
}