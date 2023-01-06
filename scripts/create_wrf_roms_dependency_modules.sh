#!/bin/bash -e

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# create destination directory
custom_full_modules_dir_zen3_gcc="${INSTALL_PREFIX}/${custom_modules_dir}/zen3/gcc/${gcc_version}/${custom_modules_suffix}"
mkdir -p "${custom_full_modules_dir_zen3_gcc}"

ENVS_DIR="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

# wrf dependency module
for pkg in wrf roms;
do
    "${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_dependencies_metamodule.sh" ${pkg} "${ENVS_DIR}/env_${pkg}" "${custom_full_modules_dir_zen3_gcc}"
    # hiding wrf/roms dependency modules for now
    mv "${custom_full_modules_dir_zen3_gcc}/${pkg}-dependency-set.lua" "${custom_full_modules_dir_zen3_gcc}/.${pkg}-dependency-set.lua"
done