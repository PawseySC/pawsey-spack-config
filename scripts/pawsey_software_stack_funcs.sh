#!/bin/bash
# Functions used by the installation scripts.

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
        ARCH =$( uname -m )
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
        
        export INSTALL_PREFIX="${INSTALL_PREFIX}/${DATE_TAG}"
    fi
}

function set_spack_config_repo()
{
    PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

}

function set_compilation_sets_for_arch()
{
    # Set compilation sets based on architecture of the system on which the script is run.
    # This is used to determine which compilers and architectures to use when installing software.
    # Allows for launching of installation process on 
    if [ "$( uname -m )" == "x86_64" ]; then
        export mainarch="zen3"
        export archs=("zen2" "zen3")
        export maincompiler="gcc@${gcc_version}"
        export compilers=("gcc@${gcc_version}" "cce@${cce_version}" "aocc@${aocc_version}")
	export pythoncompilers=("gcc@${gcc_version}" "cce@${cce_version}" "aocc@${aocc_version}")
    elif [ "$( uname -m )" == "aarch64" ]; then
        export mainarch="neoverse_v2"
        export archs=("neoverse_v2")
        export maincompiler="nvhpc@${nvidia_version}"
        export compilers=("nvhpc@${nvidia_version}")
	export pythoncompilers=("gcc@${gcc_version}")
    else
        echo "The architecture '$( uname -m )' is not supported."
        exit 1
    fi   
}

function set_modulepaths_for_arch()
{

    if [ "$( uname -m )" == "x86_64" ]; then
        module load cpe/25.03
        module load gcc-native/${gcc_version}
        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        # swap is needed for the pawsey_temp module to work
        #module swap PrgEnv-gnu PrgEnv-cray
        #module swap PrgEnv-cray PrgEnv-gnu
        module use $INSTALL_PREFIX/modules/${mainarch}/gcc/${gcc_version}/programming-languages
        module load spack/${spack_version}
    elif [ "$( uname -m )" == "aarch64" ]; then
        module load cpe/25.03
        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        module use $INSTALL_PREFIX/modules/${mainarch}/nvhpc/${nvidia_version}/programming-languages
        module load spack/${spack_version}
    else
        echo "The architecture '$( uname -m )' is not supported."
        exit 1
    fi
}

function build_environment() {
    # build an evnironment given directory and name
    local envdir=$1
    local env=$2
    local testing_only=0
    if [ ! -z ${3+x} ]; then
        testing_only=$3
    fi
    echo "Installing environment $env..."
    cd ${envdir}/${env}
    spack env activate ${envdir}/${env}
    # standard practice is to concretize in environments, but this can result in lots of duplicates
    # thus only do if explicitly requested
    if [ ! -z ${SPACK_ENV_CONCRETIZE+x} ]; then
        echo "Using concreitization for $env"
        spack concretize -f ${SPACK_CONCRETIZE_ARGS}
        if (( $testing_only != 0 )); then
            echo "Testing only - not installing for $env"
            spack env deactivate
            return
        fi
        if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
            sg $INSTALL_GROUP -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} --only dependencies"
        else
            sg $INSTALL_GROUP -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS}"
        fi
        spack env deactivate
    else
        # instead of conretizing in the environment, which tends to produce lots of duplicates,
        # just use spack find to get the basic spec being requested
        echo "Using basic spec extraction and spec and install outside environment for $env"
        rm -f spack.specs.txt spack.specs.output.txt
        local str=" - "
        spack find -c -r | awk  "/^$str/{print}" | sed "s: - ::g" > spack.specs.txt
        spack env deactivate
        if (( $testing_only != 0 )); then
            echo "Testing only - not installing for $env"
        fi
        echo "Number of specs to be processed for $env: $(wc -l spack.specs.txt)"
        while read p; do
            echo "Package $p ..."
            if (( $testing_only != 0 )); then
                spack spec ${SPACK_SPEC_ARGS} ${p} >> spack.specs.output.txt
            else
                if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
                    sg $INSTALL_GROUP -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} --only dependencies ${p}"
                else
                    sg $INSTALL_GROUP -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} ${p}"
                fi
            fi
        done < spack.specs.txt
    fi
    cd -
}


# export relevant functions
export -f check_installation_environment
export -f set_spack_config_repo
export -f set_compilation_sets_for_arch
export -f set_modulepaths_for_arch
export -f build_environment
