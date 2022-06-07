#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# list of module categories included in variables.sh (sourced above)

archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p ${root_dir}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}
    for category in $module_cat_list; do
      mkdir -p ${root_dir}/modules/${arch}/${compiler}/${category}
    done
  done
done
mkdir -p ${root_dir}/${shpc_containers_modules_dir}
mkdir -p ${root_dir}/${utilities_modules_dir}
