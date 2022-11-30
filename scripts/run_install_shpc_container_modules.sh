#!/bin/bash

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

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
