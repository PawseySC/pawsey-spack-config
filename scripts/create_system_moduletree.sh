#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
# This script only creates directories. Avoid loading modules here because it is
# called during initial Spack setup before pawseyenv/spack modules exist.

# list of module categories included in variables.sh (sourced above)

#archs="zen3 zen2"
#compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
if [ -n "${module_tree_arch_list+x}" ] || [ -n "${module_tree_compiler_list+x}" ]; then
  tree_archs="${module_tree_arch_list:-${archs}}"
  tree_compilers="${module_tree_compiler_list:-${compilers}}"
  for arch in $tree_archs; do
    for compiler in $tree_compilers; do
      mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}
      for category in $module_cat_list; do
        mkdir -p ${INSTALL_PREFIX}/modules/${arch}/${compiler}/${category}
      done
    done
  done
else
  for arch in $archs; do
    for compiler in $compilers; do
      mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}
      for category in $module_cat_list; do
        mkdir -p ${INSTALL_PREFIX}/modules/${arch}/${compiler}/${category}
      done
    done
  done
fi
if [ "${SYSTEM}" != "setonix-q" ]; then
  mkdir -p ${INSTALL_PREFIX}/${shpc_containers_modules_dir}
fi
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
