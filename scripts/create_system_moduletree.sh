#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
# This script only creates directories. Avoid loading modules here because it is
# called during initial Spack setup before pawseyenv/spack modules exist.

# Architecture lists from the shared helper are arrays; retain every target.
tree_archs="${module_tree_arch_list:-${archs[*]}}"
if [ -n "${module_tree_compiler_list+x}" ]; then
  tree_compilers="${module_tree_compiler_list}"
else
  tree_compilers=""
  for compiler in "${compilers[@]}"; do
    tree_compilers+="${compiler/@/\/} "
  done
fi
for arch in $tree_archs; do
  for compiler in $tree_compilers; do
    mkdir -p "${INSTALL_PREFIX}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}"
    for category in $module_cat_list; do
      mkdir -p "${INSTALL_PREFIX}/modules/${arch}/${compiler}/${category}"
    done
  done
done
if [ "${SYSTEM}" != "setonix-q" ]; then
  mkdir -p ${INSTALL_PREFIX}/${shpc_containers_modules_dir}
fi
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
