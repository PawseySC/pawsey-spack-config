#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

# initialise spack 
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# Initialise GPG keys to sign build cache
# This needs to be run on login nodes seems like.
if [ ${SPACK_POPULATE_CACHE} -eq 1 ]; then
    spack gpg init
    spack gpg create Spack spack@pawsey.org.au

    # Create/add mirror
    spack mirror add systemwide_buildcache "${SPACK_BUILDCACHE_PATH}"
fi

# make sure Clingo is bootstrapped
echo "Running 'spack spec nano' to bootstrap Clingo.."
spack spec nano

reset_spack_install_receipt standalone reframe

if [ "${SYSTEM}" = "setonix" ]; then
    # Preserve the Setonix/main ReFrame bootstrap behaviour: check GCC and CCE
    # concretization, but install the GCC build only.
    echo "Concretization of Reframe.."
    spack spec reframe@${reframe_version} %gcc@${gcc_version}
    spack spec reframe@${reframe_version} %cce@${cce_version}

    echo "Installing Reframe with default compilers.."
    for arch in $archs; do
        reframe_spec="reframe@${reframe_version} %gcc@${gcc_version} target=${arch}"
        install_and_record_spack_root standalone reframe "${reframe_spec}" root
        #sg $INSTALL_GROUP -c "spack install --no-checksum reframe@${reframe_version} %cce@18.0.1 ^py-maturin@1.1.0%gcc@14.2.0 target=$arch"
        #sg $INSTALL_GROUP -c "spack install --no-checksum reframe@${reframe_version} %cce@${cce_version} target=$arch"
    done
else
    for comp in ${pythoncompilers[@]}; do
        for arch in ${archs[@]}; do
            reframe_spec="reframe@${reframe_version} %${comp} target=${arch}"
            echo "Concretization of ReFrame with $comp for $arch.."
            echo "Installing ReFrame with $comp for $arch.."
            install_and_record_spack_root standalone reframe "${reframe_spec}" root
        done
    done
fi

seal_spack_install_receipt standalone reframe
