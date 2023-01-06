#!/bin/bash -e

# source setup variables
# if copy/pasting these commands, need to run from this directory
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

# list of module categories included in variables.sh (sourced above)

archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
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
