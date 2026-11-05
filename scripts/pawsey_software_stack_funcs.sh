#!/bin/bash
# Functions used by the installation scripts.

. "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/install_manifest/functions.sh"

function check_installation_environment() {
    # Checks environment variables and sets defaults if needed.
    if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
        SYSTEM="$PAWSEY_CLUSTER"
    fi

    if [ -z ${SYSTEM+x} ]; then
        echo "The 'SYSTEM' variable is not set. Please specify the system you want to
        build Spack for."
        exit 1
    fi

    if [ -z ${INSTALL_PREFIX+x} ]; then
        if [ -z ${BASE_INSTALL_DIR+x} ]; then
            echo "The 'INSTALL_PREFIX' variable and the 'BASE_INSTALL_PREFIX' is not set. 
            Please specify where you want to install the software stack."
            exit 1
        fi
        echo "The 'INSTALL_PREFIX' variable is not set. 
        Using 'BASE_INSTALL_DIR' as fallback with 'SYSTEM' and date tag appended."
        if [ -z ${DATE_TAG+x} ]; then
            DATE_TAG=$( date +%Y.%m )
        fi
        ARCH=$( uname -m )
        if [ "$ARCH" == "x86_64" ]; then
            HOST_ARCH_NAME=""
        elif [ "$ARCH" == "aarch64" ]; then
            HOST_ARCH_NAME="aarch64"
        else
            echo "The architecture '$ARCH' is not supported."
            exit 1
        fi
        export INSTALL_PREFIX="${BASE_INSTALL_DIR}/${SYSTEM}/${HOST_ARCH_NAME}/${DATE_TAG}"
    else
        if [ -z ${DATE_TAG+x} ]; then
            DATE_TAG=$( date +%Y.%m )
            echo "The 'DATE_TAG' variable is not set. Using current date tag '$DATE_TAG'."
        fi

        if [ "${INSTALL_PREFIX%/${DATE_TAG}}" = "${INSTALL_PREFIX}" ]; then
            export INSTALL_PREFIX="${INSTALL_PREFIX}/${DATE_TAG}"
        else
            export INSTALL_PREFIX
        fi
    fi
    export DATE_TAG
}

function load_system_settings()
{
    if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
        SYSTEM="$PAWSEY_CLUSTER"
    fi

    if [ -z ${SYSTEM+x} ]; then
        echo "The 'SYSTEM' variable is not set. Please specify the system you want to
        build Spack for."
        exit 1
    fi

    local repo_candidate
    local source_file
    local source_candidates=("${BASH_SOURCE[@]}" "$0" "$PWD")

    for source_file in "${source_candidates[@]}"; do
        if [ -z "${source_file}" ] || [ "${source_file}" = "environment" ]; then
            continue
        fi

        if [ -d "${source_file}" ]; then
            repo_candidate="${source_file}"
        else
            repo_candidate=$( cd -- "$( dirname -- "${source_file}" )/.." &> /dev/null && pwd )
        fi

        if [ -f "${repo_candidate}/systems/${SYSTEM}/settings.sh" ]; then
            export PAWSEY_SPACK_CONFIG_REPO="${repo_candidate}"
            . "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"
            if [ -z "${NCPUS+x}" ] && [ -n "${NPROCS+x}" ]; then
                export NCPUS="${NPROCS}"
            fi
            return
        fi
    done

    echo "Could not find systems/${SYSTEM}/settings.sh."
    exit 1
}

function set_spack_config_repo()
{
    load_system_settings
}

function set_compilation_sets_for_arch()
{
    # Set compilation sets based on architecture of the system on which the script is run.
    # This is used to determine which compilers and architectures to use when installing software.
    # Allows for launching of installation process on 
    local host_arch
    host_arch="$( uname -m )"

    if [ "${SYSTEM}" = "setonix-q" ] && [ "${host_arch}" != "aarch64" ]; then
        echo "The setonix-q software stack must be built on aarch64; detected '${host_arch}'."
        exit 1
    fi

    if [ "${host_arch}" == "x86_64" ]; then
        export mainarch="zen3"
        export archs=("zen2" "zen3")
        export maincompiler="gcc@${gcc_version}"
        export compilers=("gcc@${gcc_version}" "cce@${cce_version}" "aocc@${aocc_version}")
	export pythoncompilers=("gcc@${gcc_version}" "cce@${cce_version}")
    elif [ "${host_arch}" == "aarch64" ]; then
        export mainarch="neoverse_v2"
        export archs=("neoverse_v2")
        export maincompiler="gcc@${gcc_version}"
        export compilers=("gcc@${gcc_version}" "nvhpc@${nvidia_version}")
	export pythoncompilers=("gcc@${gcc_version}")
    else
        echo "The architecture '${host_arch}' is not supported."
        exit 1
    fi   
}

function check_python_version()
{
    local python_interpreter="${1-python}"
    "${python_interpreter}" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1
}


function resolve_compatible_python_interpreter()
{
    local python_interpreter="${1-${SPACK_PYTHON:-python}}"

    # If no interpreter is explicitly provided and SPACK_PYTHON is not set, attempt to load a suitable module.
    if [ "$#" -eq 0 ] && [ -z "${SPACK_PYTHON:-}" ] && ! check_python_version "${python_interpreter}"; then
        # Try Spack-provided Python first, then fall back to cray-python.
        if ! module load "python/${python_version}" 2>/dev/null; then
            module load cray-python || {
                echo "Could not load python/${python_version} or cray-python." >&2
                return 1
            }
        fi
    fi

    if ! check_python_version "${python_interpreter}"; then
        echo "Python interpreter '${python_interpreter}' is not compatible; must be +3.8." >&2
        return 1
    fi

    export SPACK_PYTHON="$(command -v "${python_interpreter}")"
}

function bootstrap()
{
    # Prepare the host compiler and Python before setting up Spack.
    if [ "${SYSTEM}" = "ella" ]; then
        export PATH="${GCC_INSTALL_PREFIX}/bin:${PATH}"
        export LD_LIBRARY_PATH="${GCC_INSTALL_PREFIX}/lib64:${GCC_INSTALL_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        resolve_compatible_python_interpreter "${BOOTSTRAP_PYTHON}"
    else
        resolve_compatible_python_interpreter
    fi
}

function set_modulepaths_for_arch()
{

    if [ "${SYSTEM}" = "ella" ]; then
        module use "${INSTALL_PREFIX}/staff_modulefiles" || return 1
        module --ignore-cache load "pawseyenv/${pawseyenv_version}" || return 1
        module load "${gcc_module}" "spack/${spack_version}" || return 1
    elif [ "$( uname -m )" == "x86_64" ]; then
        module load cpe/25.03
        # The Setonix module is named for its major/minor version (14.2), while
        # the Spack compiler and module tree use the full version (14.2.0).
        module load gcc-native/${gcc_version%.*}
        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        # swap is needed for the pawsey_temp module to work
        #module swap PrgEnv-gnu PrgEnv-cray
        #module swap PrgEnv-cray PrgEnv-gnu
        module use $INSTALL_PREFIX/modules/${mainarch}/gcc/${gcc_version}/programming-languages
        module load spack/${spack_version}
    elif [ "$( uname -m )" == "aarch64" ]; then
        if [ "${SYSTEM}" != "setonix-q" ]; then
            echo "The aarch64 module path setup is only configured for SYSTEM=setonix-q."
            exit 1
        fi

        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        # CUDA-free base: the plain GNU programming environment keeps the CUDA
        # toolkit out of the base that every build inherits, so pure %gcc CPU
        # builds (e.g. openblas) do not pick up CUDA. nvhpc (GPU) builds
        # family-swap to the stock NVIDIA PE via the compiler entry; gcc+CUDA
        # packages get CUDA from the `cuda` external in packages.yaml.
        module load PrgEnv-gnu
        # Pin the GNU compiler; plain PrgEnv-gnu otherwise defaults to a newer
        # gcc-native (e.g. 14.2) than the gcc@${gcc_version} compiler entry.
        module load gcc-native/${gcc_version%%.*}
        # Target the Grace ARM CPU (the cluster default is craype-x86-milan).
        module load craype-arm-grace
        # The gcc Spack module tree (which holds the python module that `module
        # load spack` pulls in) is exposed via the pawseyenv + gcc-native
        # handshake (LMOD_CUSTOM_COMPILER_GNU_* prepended to MODULEPATH), so no
        # explicit `module use` of the programming-languages trees is needed.
        module load spack/${spack_version}
    else
        echo "The architecture '$( uname -m )' is not supported."
        exit 1
    fi
}

function cleanup_software_stack()
{
    [ "${SYSTEM}" = "setonix-q" ] || [ "${SYSTEM}" = "ella" ] || return 0
    echo "Cleaning packages outside the deployment inventory.."
    . "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh" || return 1
    cleanup_spack_installation "${SPACK_INSTALL_MANIFEST}" --apply
}

# Install a saved environment on Setonix-Q/Ella; other systems concretize here.
function build_environment() {
    local envdir=$1
    local env=$2
    local testing_only=0
    local previous_dir=$PWD
    local lock_file
    local manifest_checksum
    local concrete_only=""
    if [ "${SYSTEM}" = "setonix-q" ] || [ "${SYSTEM}" = "ella" ]; then
        envdir="${INSTALLATION_METADATA_DIR}/environments"
        manifest_checksum=$(cksum < "${SPACK_INSTALL_MANIFEST}") || return 1
        "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" validate \
            --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}" \
            --manifest "${SPACK_INSTALL_MANIFEST}" || return 1
        concrete_only="--only-concrete"
    fi
    if [ ! -z ${3+x} ]; then
        testing_only=$3
    fi
    echo "Installing environment $env..."
    cd "${envdir}/${env}" || return 1
    if ! spack env activate "${envdir}/${env}"; then
        cd "${previous_dir}" || true
        return 1
    fi
    if [ "${SYSTEM}" = "setonix-q" ] || [ "${SYSTEM}" = "ella" ]; then
        lock_file="${envdir}/${env}/spack.lock"
        if [ ! -f "${lock_file}" ]; then
            echo "Environment ${env} has no spack.lock; run concretize_environments.sh first."
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
        echo "Using existing environment concretization for $env"
    else
        echo "Using environment concretization for $env"
        if ! spack concretize -f ${SPACK_CONCRETIZE_ARGS}; then
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
    fi
    if (( $testing_only != 0 )); then
        echo "Testing only - not installing for $env"
        spack env deactivate
        cd "${previous_dir}" || true
        return
    fi
    if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
        if ! sg "${INSTALL_GROUP}" -c \
            "spack install ${concrete_only} ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} --only dependencies"; then
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
    else
        local install_target
        local install_targets=("")
        # CUDA is external to Spack but supplied by this SDK: install it first.
        if [ "${SYSTEM}" = "ella" ] && [ "${env}" = "${bootstrap_environment}" ]; then
            install_targets=("nvhpc" "")
        fi
        for install_target in "${install_targets[@]}"; do
            if ! sg "${INSTALL_GROUP}" -c \
                "spack install ${concrete_only} ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} ${install_target}"; then
                spack env deactivate || true
                cd "${previous_dir}" || true
                return 1
            fi
        done
    fi
    if [ "${SYSTEM}" = "setonix-q" ] || [ "${SYSTEM}" = "ella" ]; then
        if ! "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" validate \
            --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}" \
            --manifest "${SPACK_INSTALL_MANIFEST}"; then
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
        if [ "$(cksum < "${SPACK_INSTALL_MANIFEST}")" != "${manifest_checksum}" ]; then
            echo "Manifest changed during installation" >&2
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
    fi
    spack env deactivate || return 1
    cd "${previous_dir}" || return 1
}


# export relevant functions
export -f check_installation_environment
export -f load_system_settings
export -f set_spack_config_repo
export -f set_compilation_sets_for_arch
export -f set_modulepaths_for_arch
export -f check_python_version
export -f resolve_compatible_python_interpreter
export -f bootstrap
export -f cleanup_software_stack
export -f build_environment
