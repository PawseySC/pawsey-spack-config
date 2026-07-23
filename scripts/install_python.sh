#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

# for first run, use cray-python, because there is no Spack python yet
module load cray-python
SPACK_PYTHON="$CRAY_PYTHON_PREFIX/bin/python3"

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
echo "Running 'spack spec nano %${main_compiler} target=${main_arch}' to bootstrap Clingo.."
spack spec nano %${main_compiler} target=${main_arch}

reset_spack_install_receipt standalone python

# first thing we need is Python
for comp in ${pythoncompilers[@]}; do
    for arch in ${archs[@]}; do
        python_spec="python@${python_version} %${comp} target=${arch}"
        echo "Concretization of Python with $comp for $arch .."
        echo "Installing Python with $comp for $arch.."
        install_and_record_spack_root standalone python "${python_spec}" root
    done
done

seal_spack_install_receipt standalone python
