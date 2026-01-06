#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

# list of module categories included in variables.sh (sourced above)

#archs="zen3 zen2"
#compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}
    for category in $module_cat_list; do
      mkdir -p ${INSTALL_PREFIX}/modules/${arch}/${compiler}/${category}
    done
  done
done
mkdir -p ${INSTALL_PREFIX}/${shpc_containers_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
