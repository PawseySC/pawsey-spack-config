#!/bin/bash -e

set_spack_config_repo
check_installation_environment
set_compilation_sets_for_arch

if [ -n "${bootstrap_environment:-}" ]; then
    exec "${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_bootstrap.sh"
fi

resolve_compatible_python_interpreter || exit 1

# initialise spack 
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# Initialise GPG keys to sign build cache
# This needs to be run on login nodes seems like.
if [ ${SPACK_POPULATE_CACHE} -eq 1 ]; then
    spack gpg init
    spack gpg create Spack spack@pawsey.org.au
fi

# make sure Clingo is bootstrapped
echo "Running 'spack spec nano' to bootstrap Clingo.."
spack spec nano

# first thing we need is Python
for comp in ${pythoncompilers[@]}; do
    for arch in ${archs[@]}; do
        echo "Concretization of Python with $comp for $arch .."
        echo "Installing Python with $comp for $arch.."
        spack spec python@${python_version} %$comp target=$arch
        sg $INSTALL_GROUP -c "spack install -j${NCPUS} --no-checksum python@${python_version} %$comp target=$arch"
    done
done
