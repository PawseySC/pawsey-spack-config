#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# load shpc module
module load ${shpc_name}/${shpc_version}

# source list of containers to be installed by shpc
. ${script_dir}/list_shpc_container_modules.sh

# make sure root directory exists, for container modules installation
mkdir -p ${root_dir}/${containers_root_dir}

# install container modules
# will take a while (container downloads)
# if a container module has already been installed, its installation will complete quickly
for container in $container_list ; do
  shpc install $container
done

# create compact, symlinked module tree
bash ${script_dir}/post_create_shpc_symlink_modules.sh
# it's the symlinked module tree that needs to go in MODULEPATH:
# `module use ${root_dir}/containers/${shpc_spackuser_modules_dir_short}`
