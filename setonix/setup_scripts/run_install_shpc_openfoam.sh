#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# load shpc module
module load ${shpc_name}/${shpc_version}

# list of openfoam containers to be installed by shpc
container_list="
quay.io/pawsey/openfoam:v2012
quay.io/pawsey/openfoam:v2006
quay.io/pawsey/openfoam:v1912
quay.io/pawsey/openfoam:v1812
quay.io/pawsey/openfoam:v1712
quay.io/pawsey/openfoam-org:8
quay.io/pawsey/openfoam-org:7
quay.io/pawsey/openfoam-org:5.x
quay.io/pawsey/openfoam-org:2.4.x
quay.io/pawsey/openfoam-org:2.2.0
"

# directory with pawsey edited shpc recipes
recipes_dir="${script_dir}/../shpc_registry"
# target directory for SIF symlinks
sif_symlink_dir="${root_dir}/containers/openfoam-sif"

# make sure root directory exists, for container modules installation
mkdir -p ${root_dir}/${containers_root_dir}
# and for SIF symlinks
mkdir -p ${sif_symlink_dir}

# install container modules
# will take a while (container downloads)
# if a container module has already been installed, its installation will complete quickly
for container in $container_list ; do
  tool_repo="${container%:*}"
  tool="${tool_repo##*/}"
  version="${container#*:}"
  tool_dir="${container/:/\/}"
  tool_file_prefix="${container//\//-}"
  tool_file_prefix="${tool_file_prefix/:/-}"
# add version specific command aliases to recipe
# might not be needed in future shpc versions
  container_recipe_dir="${recipes_dir}/${tool_repo}"
  cp ${container_recipe_dir}/template_container.yaml ${container_recipe_dir}/container.yaml 
  cat ${container_recipe_dir}/aliases/${version}.yaml >>${container_recipe_dir}/container.yaml 

  shpc install $container

# remove edited recipe that has command aliases
  rm ${container_recipe_dir}/container.yaml 

# fix conflict line in modulefile, it is too long
  modulefile="${root_dir}/${containers_root_dir}/${shpc_spackuser_modules_dir_long}/${tool_dir}/module.lua"
  new_conflict="conflict(\"${tool}\",\"${tool_repo}\")"
  sed -i '/conflict(/c '"${new_conflict}"'' ${modulefile}

# add symlink to SIF image
  src_sif="${root_dir}/${shpc_containers_dir}/${tool_dir}/${tool_file_prefix}-sha256*.sif"
  dst_sif="${sif_symlink_dir}/${tool}_${version}.sif"
  rm -f ${dst_sif}
  ln -s ${src_sif} ${dst_sif}
done

# create compact, symlinked module tree
bash ${script_dir}/post_create_shpc_symlink_modules.sh
# it's the symlinked module tree that needs to go in MODULEPATH:
# `module use ${root_dir}/containers/${shpc_spackuser_modules_dir_short}`
