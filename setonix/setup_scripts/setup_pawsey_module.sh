#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(dirname $0 2>/dev/null || pwd)"
. ${script_dir}/variables.sh

# This script just does one thing
# It creates a template for the pawsey module,
# inside ${root_dir},
# containing the software stack related snippet,
# to be handed over to the Platforms team

cd ${root_dir}

sed \
  -e "s/TOP_ROOT_DIR/${top_root_dir}/g" \
  -e "s/CUSTOM_MODULES_DIR/${custom_modules_dir}/g" \
  -e "s/UTILITIES_MODULES_DIR/${utilities_modules_dir}/g" \
  -e "s/SHPC_CONTAINERS_MODULES_DIR/${shpc_containers_modules_dir}/g" \
  -e "s/GCC_VERSION/${gcc_version}/g" \
  -e "s/CCE_VERSION/${cce_version}/g" \
  -e "s/AOCC_VERSION/${aocc_version}/g" \
  pawsey-spack-config/setonix/setup_scripts/module_pawsey_load_first.lua \
  > ${root_dir}/pawsey_load_first.lua
