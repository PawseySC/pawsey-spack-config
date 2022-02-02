#!/bin/bash

# TODO: most of this to be turned into Spack recipe

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# load needed python toolkit
module load $python_module/$python_version
module load setuptools/$setuptools_version
module load pip/$pip_version

# create and enter install directory
mkdir shpc
cd shpc

# pip install package
pip install --prefix=$(pwd) singularity-hpc==$shpc_version

# get registry from github repo
git clone https://github.com/singularityhub/singularity-hpc
cd singularity-hpc
# checkout registry, too, for reproducibility
git checkout $shpc_version
cd ..
mv singularity-hpc/registry .
cd lib/python${python_version_major}.${python_version_minor}/site-packages
# symlink here, so that registry is in a more visible location
ln -s ../../../registry .
cd ../../..
rm -fr singularity-hpc

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/spython

# need to configure shpc for use, to change configs
export PATH=$(pwd)/bin:$PATH
export PYTHONPATH=$(pwd)/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

#### ALL SHPC CONFIG COMMANDS HERE
# in alternative, we could provide edited yamls, just to copy over
## ALL USERS
# user install location for modulefiles
shpc config set module_base:/software/\$PAWSEY_PROJECT/\$USER/setonix/containers/modules
# user install location for containers
shpc config set container_base:/software/\$PAWSEY_PROJECT/\$USER/setonix/containers/sif
# custom Pawsey registry
shpc config add registry:/software/setonix/2022.01/pawsey-spack-config/setonix/registry_setonix
# singularity module
shpc config set singularity_module:singularity/3.8.5
# disable default version for modulefiles
shpc config set default_version:false
# enable wrapper scripts
#shpc config set wrapper_scripts:true
# GPU support (Phase 2)
#shpc config set container_features:gpu:amd
# enable X11 graphics
shpc config set container_features:x11:true
# location for container fake home
shpc config set container_features:home:\$HOME/.shpc_home

## SPACK USER
shpc config inituser
# system install location for modulefiles
shpc config set module_base:/software/setonix/2022.01/containers/modules
# system install location for containers
shpc config set container_base:/software/setonix/2022.01/containers/sif

cd ..
