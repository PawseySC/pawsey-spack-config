#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# define source and destination directories for container modulefiles
source_dir="${root_dir}/${containers_root_dir}/${shpc_spackuser_modules_dir_long}"
target_dir="${root_dir}/${shpc_containers_modules_dir}"

# delete previous symlink tree
echo "You are about to delete the following item:"
echo "  ${target_dir}"
echo "Does this directory correspond to the shpc symlink moduletree?"
echo "Do you want to delete it? (yes/no)"
read shpc_answer
if [ ${shpc_answer,,} == "yes" ] ; then
  rm -r ${target_dir}
else
  echo "Skipping deletion of shpc symlink moduletree. Stopping process to create new shpc symlink moduletree."
  exit 1
fi
# create base directory for symlinked module tree
mkdir -p ${target_dir}

# create symlinks
# NOTE: assumes all container module paths finish with: <tool>/<ver>/module.lua
find ${source_dir} -name 'module.lua' | while read m ; do 
  mbase=${m%/module.lua}
  mver=${mbase##*/}
  mtmp=${mbase%/*}
  mtool=${mtmp##*/}

  if [[ "${mtool}" =~ "openfoam" ]] || [[ "${mtool}" =~ "hpc-python" ]] ; then
    mtool=${mtool}${shpc_spackuser_container_tag}
  fi

  mkdir -p ${target_dir}/${mtool}
  ln -s ${m} ${target_dir}/${mtool}/${mver}.lua
done
