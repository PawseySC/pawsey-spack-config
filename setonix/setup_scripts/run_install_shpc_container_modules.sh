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
mkdir -p ${INSTALL_PREFIX}/${containers_root_dir}

# install container modules
# will take a while (container downloads)
# if a container module has already been installed, its installation will complete quickly
for container in $container_list ; do
  shpc install $container
done

# customise Pawsey container modules
bash ${script_dir}/post_customise_shpc_pawsey_modules.sh
