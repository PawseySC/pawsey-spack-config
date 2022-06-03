#!/bin/bash

gcc_version="GCC_VERSION"
aocc_version="AOCC_VERSION"
cce_version="CCE_VERSION"

project_modules_suffix="PROJECT_MODULES_SUFFIX"
user_modules_suffix="USER_MODULES_SUFFIX"
project_root_dir="/software/projects/${PAWSEY_PROJECT}/setonix"
user_root_dir="/software/projects/${PAWSEY_PROJECT}/${USER}/setonix"

archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"

for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p "${project_root_dir}/modules/${arch}/${compiler}/${project_modules_suffix}"
    mkdir -p "${user_root_dir}/modules/${arch}/${compiler}/${user_modules_suffix}"
  done
done
chmod -R g+rwX "${project_root_dir}/modules"

mkdir -p "${user_root_dir}/${shpc_containers_modules_dir}"
