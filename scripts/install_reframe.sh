#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

# initialise spack 
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# GPG/buildcache setup is performed by install_python.sh. The shared install
# helper checks bootstrap dependencies so this script can also be retried alone.
# if [ ${SPACK_POPULATE_CACHE} -eq 1 ]; then
#     spack gpg init
#     spack gpg create Spack spack@pawsey.org.au
#     spack mirror add systemwide_buildcache "${SPACK_BUILDCACHE_PATH}"
# fi
# echo "Running 'spack spec nano' to bootstrap Clingo.."
# spack spec nano

if [ "${SYSTEM}" = "setonix-q" ]; then
    reset_spack_install_receipt standalone reframe
fi

if [ "${SYSTEM}" = "setonix" ]; then
    # Check both compiler toolchains, and install the GCC build for each target.
    for arch in "${archs[@]}"; do
        for comp in "${pythoncompilers[@]}"; do
            toolchain="${comp%%@*}_compiler"
            if [ "${arch}" = "zen2" ]; then
                toolchain+="_zen2"
            fi
            reframe_spec="reframe@${reframe_version} target=${arch} %${toolchain}"
            echo "Concretization of ReFrame with $comp for $arch.."
            spack spec ${reframe_spec}
            if [[ "${comp}" == gcc@* ]]; then
                echo "Installing ReFrame with $comp for $arch.."
                sg "$INSTALL_GROUP" -c "spack install -j${NCPUS} --no-checksum ${reframe_spec}"
            fi
        done
    done
elif [ "${SYSTEM}" = "setonix-q" ]; then
    for comp in ${pythoncompilers[@]}; do
        for arch in ${archs[@]}; do
            reframe_spec="reframe@${reframe_version} target=${arch} %${comp%%@*}_compiler"
            echo "Concretization of ReFrame with $comp for $arch.."
            echo "Installing ReFrame with $comp for $arch.."
            install_and_record_spack_root standalone reframe "${reframe_spec}" root
        done
    done
else
    for comp in ${pythoncompilers[@]}; do
        for arch in ${archs[@]}; do
            echo "Concretization of ReFrame with $comp for $arch.."
            spack spec --reuse reframe@${reframe_version} %$comp target=$arch
            echo "Installing ReFrame with $comp for $arch.."
            sg $INSTALL_GROUP -c "spack install -j${NCPUS} --no-checksum --reuse reframe@${reframe_version} %$comp target=$arch"
        done
    done
fi

if [ "${SYSTEM}" = "setonix-q" ]; then
    seal_spack_install_receipt standalone reframe
fi
