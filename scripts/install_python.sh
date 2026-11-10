#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

# for first run, use cray-python, because there is no Spack python yet
module load cray-python
if [ "${SYSTEM}" = "setonix-q" ]; then
    SPACK_PYTHON="$CRAY_PYTHON_PREFIX/bin/python3"
fi

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
if [ "${SYSTEM}" = "setonix-q" ]; then
    echo "Running 'spack spec nano target=${main_arch} %${main_compiler}_compiler' to bootstrap Clingo.."
    spack spec nano target=${main_arch} %${main_compiler}_compiler
else
    echo "Running 'spack spec nano' to bootstrap Clingo.."
    spack spec nano
fi

if [ "${SYSTEM}" = "setonix-q" ]; then
    reset_spack_install_receipt standalone python
fi

# first thing we need is Python
for comp in ${pythoncompilers[@]}; do
    for arch in ${archs[@]}; do
        echo "Concretization of Python with $comp for $arch .."
        echo "Installing Python with $comp for $arch.."
        toolchain="${comp%%@*}_compiler"
        if [ "${SYSTEM}" = "setonix" ] && [ "${arch}" = "zen2" ]; then
            toolchain+="_zen2"
        fi
        python_spec="python@${python_version} target=${arch} %${toolchain}"
        if [ "${SYSTEM}" = "setonix-q" ]; then
            install_and_record_spack_root standalone python "${python_spec}" root
        else
            spack spec ${python_spec}
            sg $INSTALL_GROUP -c "spack install -j${NCPUS} --no-checksum ${python_spec}"
        fi
    done
done

if [ "${SYSTEM}" = "setonix-q" ]; then
    seal_spack_install_receipt standalone python
fi
