#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# for provisional setup (no spack modulepaths yet)
is_avail_spack="$( module is-avail spack/${spack_version} ; echo "$?" )"
if [ "${is_avail_spack}" != "0" ] ; then
  module use ${root_dir}/${pawsey_temp}
  module load ${pawsey_temp}
  module swap PrgEnv-gnu PrgEnv-cray
  module swap PrgEnv-cray PrgEnv-gnu
  module swap gcc gcc/${gcc_version}
fi

# load shpc module
module load ${shpc_name}/${shpc_version}

# source list of containers to be installed by shpc
. ${script_dir}/list_shpc_container_modules.sh

# make sure root directory exists, for container modules installation
cd ${root_dir}
mkdir -p ${containers_root_dir}

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
