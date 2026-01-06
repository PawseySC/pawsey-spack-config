#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

# create destination directory
custom_full_modules_dir_zen3_gcc="${INSTALL_PREFIX}/${custom_modules_dir}/zen3/gcc/${gcc_version}/${custom_modules_suffix}"
mkdir -p "${custom_full_modules_dir_zen3_gcc}"

ENVS_DIR="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

# wrf dependency module
for pkg in wrf roms;
do
    "${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_dependencies_metamodule.sh" ${pkg} "${ENVS_DIR}/${pkg}" "${custom_full_modules_dir_zen3_gcc}"
    # hiding wrf/roms dependency modules for now
    mv "${custom_full_modules_dir_zen3_gcc}/${pkg}-dependency-set.lua" "${custom_full_modules_dir_zen3_gcc}/.${pkg}-dependency-set.lua"
done
