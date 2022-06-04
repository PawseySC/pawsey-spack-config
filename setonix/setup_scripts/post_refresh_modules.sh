#!/bin/bash

# this script goes through 5 steps
# 1. refresh spack modules
# 2. update singularity modules
# 3. generate modulerc to hide dependency modules
# 4. refresh shpc symlink modules
# 5. creates all missing module directories

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# for provisional setup (no spack modulepaths yet)
is_avail_spack="$( module is-avail spack/${spack_version} ; echo "$?" )"
if [ "${is_avail_spack}" != "0" ] ; then
  module use ${root_dir}/${pawsey_temp}
  module load ${pawsey_temp}
  module swap PrgEnv-cray PrgEnv-gnu
  module swap gcc gcc/${gcc_version}
fi
# spack module
is_loaded_spack="$( module is-loaded spack/${spack_version} ; echo "$?" )"
if [ "${is_loaded_spack}" != "0" ] ; then
  module load spack/${spack_version}
fi


# step 1. refresh spack modules
echo "Refreshing Spack modules.."
echo "Do you want to refresh the Spack modules? (yes/no)"
read spack_answer
if [ ${spack_answer,,} == "yes" ] ; then
  echo "Refreshing Spack modules.."
  spack module lmod refresh -y --delete-tree
else
  echo "Skipping refresh of Spack modules."
fi


# step 2. update singularity modules
echo "Updating Singularity modules"
bash "${script_dir}/setup_singularity_pawsey_modules.sh"


# step 3. generate modulerc to hide dependency modules
echo "Generating modulerc.lua to hide dependency modules"
archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
for arch in $archs; do
  for compiler in $compilers; do
    target_dir="${root_dir}/modules/$arch/$compiler/dependencies"
    modulerc_file="${target_dir}/.modulerc.lua"
    echo "-- Hiding dependency modules" >"${modulerc_file}"
    find ${target_dir} -name '*.lua' |grep -v modulerc |while read m ; do 
      m1=$(readlink -f $m)
      m2="${m1/2022.05/current}"
      echo "hide_modulefile(\"$m1\")"
      echo "hide_modulefile(\"$m2\")"
      done >>"${modulerc_file}"
  done
done


# step 4. refresh shpc symlink modules
shpc_full_containers_modules_dir="${root_dir}/${shpc_containers_modules_dir}"
echo "You are about to delete this directory and its content: ${shpc_full_containers_modules_dir}"
echo "Does this directory contain the symlink tree of SHPC container modules? Do you want to delete it? (yes/no)"
read shpc_answer
if [ ${shpc_answer,,} == "yes" ] ; then
  echo "Deleting and re-creating SHPC symlink modules.."
  rm -r ${shpc_full_containers_modules_dir}
  # source list of containers to be installed by shpc, and useful function
  . ${script_dir}/list_shpc_container_modules.sh
  create_shpc_symlink_modules
else
  echo "Skipping deletion and re-creation of SHPC symlink modules."
fi


# step 5. creates all missing module directories
echo "Creating all missing module directories.."
module_categories="
astro-applications/
bio-applications/
applications/
libraries/
programming-languages/
utilities/
visualisation/
python-packages/
benchmarking/
developer-tools/
dependencies/
"
archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"
for arch in $archs; do
  for compiler in $compilers; do
    mkdir -p ${root_dir}/${custom_modules_dir}/${arch}/${compiler}/${custom_modules_suffix}
    for category in $module_categories; do
      mkdir -p ${root_dir}/modules/${arch}/${compiler}/${category}
    done
  done
done
mkdir -p ${root_dir}/${shpc_containers_modules_dir}
mkdir -p ${root_dir}/${utilities_modules_dir}
