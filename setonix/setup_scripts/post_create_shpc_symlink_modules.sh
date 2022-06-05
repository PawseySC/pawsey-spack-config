#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# define source and destination directories for container modulefiles
source_dir="${root_dir}/${containers_root_dir}/${shpc_spackuser_modules_dir_long}"
target_dir="${root_dir}/${shpc_containers_modules_dir}"

# create base directory for symlinked module tree
mkdir -p ${target_dir}

# create symlinks
find ${source_dir} -name 'module.lua' | while read m ; do 
  mbase=${m%/module.lua}
  mver=${mbase##*/}
  mtmp=${mbase%/*}
  mtool=${mtmp##*/}

  if [ "${mtool}" == "openfoam" ] || [ "${mtool}" == "openfoam-org" ] || [ "${mtool}" == "hpc-python" ] ; then
    mtool=${mtool}${shpc_spackuser_container_tag}
  fi

  mkdir -p ${target_dir}/${mtool}
  ln -s ${mbase} ${target_dir}/${mtool}/
done
