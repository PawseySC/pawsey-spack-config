#!/bin/bash

# some variables related to the current stack
gcc_version="GCC_VERSION"
aocc_version="AOCC_VERSION"
cce_version="CCE_VERSION"
# typically these do not change
project_modules_suffix="PROJECT_MODULES_SUFFIX"
user_modules_suffix="USER_MODULES_SUFFIX"
project_root_dir="/software/projects/${PAWSEY_PROJECT}/setonix"
user_root_dir="/software/projects/${PAWSEY_PROJECT}/${USER}/setonix"

archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"

# create backbone of the user/project spack moduletree
for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p "${project_root_dir}/modules/${arch}/${compiler}/${project_modules_suffix}"
    mkdir -p "${user_root_dir}/modules/${arch}/${compiler}/${user_modules_suffix}"
  done
done
chmod --silent -R g+rwX "${project_root_dir}/modules"

# create shpc container modules base dir
mkdir -p "${user_root_dir}/${shpc_containers_modules_dir}"

# create base dir for user Spack repository of recipes
mkdir -p "${user_root_dir}/spack_repo/packages"
cat << EOF >"${user_root_dir}/spack_repo/repo.yaml"
repo:
  namespace: 'user_repo'
EOF

# create base dir for user SHPC registry of recipes
mkdir -p "${user_root_dir}/shpc_registry"