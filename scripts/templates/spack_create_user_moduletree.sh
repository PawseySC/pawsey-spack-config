#!/bin/bash

# some variables related to the current stack
gcc_version="GCC_VERSION"
aocc_version="AOCC_VERSION"
cce_version="CCE_VERSION"
# typically these do not change
project_modules_suffix="PROJECT_MODULES_SUFFIX"
user_modules_suffix="USER_MODULES_SUFFIX"
shpc_containers_modules_dir="SHPC_CONTAINERS_MODULES_DIR"
r_version_majorminor="R_VERSION_MAJORMINOR"

# for user and project directories, give option to provide project via CLI
tree_project="${1:-$PAWSEY_PROJECT}"
project_root_dir="USER_PERMANENT_FILES_PREFIX/${tree_project}/setonix/DATE_TAG"
user_root_dir="USER_PERMANENT_FILES_PREFIX/${tree_project}/${USER}/setonix/DATE_TAG"

archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"

# create backbone of the user/project spack moduletree
for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p "${project_root_dir}/modules/${arch}/${compiler}/${project_modules_suffix}"
    mkdir -p "${user_root_dir}/modules/${arch}/${compiler}/${user_modules_suffix}"
  done
done
chmod --silent g+rwX "${project_root_dir}"
chmod --silent -R g+rwX "${project_root_dir}/modules"

# create shpc user-private container modules base dir (symlinks - views)
mkdir -p "${user_root_dir}/${shpc_containers_modules_dir}"
cat << EOF >"${user_root_dir}/${shpc_containers_modules_dir}/view.yaml"
view:
  name: modules
  modules: []
  system_modules: []
EOF

# create project-wide shpc container modules base dir (symlinks - views)
mkdir -p "${project_root_dir}/${shpc_containers_modules_dir}"
cat << EOF >"${project_root_dir}/${shpc_containers_modules_dir}/view.yaml"
view:
  name: modules
  modules: []
  system_modules: []
EOF

# create base dir for user Spack repository of recipes
mkdir -p "${user_root_dir}/spack_repo/packages"
cat << EOF >"${user_root_dir}/spack_repo/repo.yaml"
repo:
  namespace: 'user_repo'
EOF

# create base dir for project-wide Spack repository of recipes
mkdir -p "${project_root_dir}/spack_repo/packages"
cat << EOF >"${project_root_dir}/spack_repo/repo.yaml"
repo:
  namespace: 'project_repo'
EOF


# create base dir for user SHPC registry of recipes
mkdir -p "${user_root_dir}/shpc_registry"
# ..and for project-wide recipes
mkdir -p "${project_root_dir}/shpc_registry"

# create base dir for Python pip user installations (PYTHONUSERBASE)
mkdir -p "${user_root_dir}/python"

# create base dir for R user installations (R_LIBS_USER)
mkdir -p "${user_root_dir}/r/${r_version_majorminor}"

# create empty control file
touch ${user_root_dir}/.created_moduletree_bases
