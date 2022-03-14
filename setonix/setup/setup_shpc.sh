#!/bin/bash

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# load needed python toolkit
module load $python_name/$python_version
module load setuptools/$setuptools_version
module load pip/$pip_version

# clone shpc repo and enter it
cd ${root_dir}
git clone https://github.com/singularityhub/singularity-hpc $shpc_name
cd $shpc_name

# checkout version, for reproducibility
git checkout $shpc_version
# install package (dev mode)
pip install --prefix=$(pwd) -e .[all]

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/spython

# need to configure shpc for use, to change configs
export PATH=$(pwd)/bin:$PATH
export PYTHONPATH=$(pwd)/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

# back to root_dir
cd ..

#### ALL SHPC CONFIG COMMANDS HERE
# in alternative, we could provide edited yamls, just to copy over

## ALL USERS
# lmod for modules
shpc config set module_sys:lmod
# singularity for containers
shpc config set container_tech:singularity
# custom Pawsey registry
shpc config add registry:${root_dir}/pawsey-spack-config/setonix/registry_setonix
# user install location for modulefiles
shpc config set module_base:/software/\$PAWSEY_PROJECT/\$USER/setonix/containers/modules
# disable default version for modulefiles
shpc config set default_version:false
# user install location for containers
shpc config set container_base:/software/\$PAWSEY_PROJECT/\$USER/setonix/containers/sif
# singularity module
shpc config set singularity_module:singularity/${singularity_version}
# enable wrapper scripts
shpc config set wrapper_scripts:enabled:true
# GPU support (Phase 2)
#shpc config set container_features:gpu:amd
# enable X11 graphics
shpc config set container_features:x11:true
# location for container fake home
shpc config set container_features:home:\$MYSOFTWARE/.${shpc_name}_home

## SPACK USER (system wide installation)
shpc config inituser
# system install location for modulefiles
shpc config set module_base:${root_dir}/containers/${shpc_spackuser_modules_dir_long}
# system install location for containers
shpc config set container_base:${root_dir}/containers/sif

# edit and copy over SHPC modulefile
mkdir -p ${root_dir}/${pawsey_modules_dir}/${shpc_name}/${shpc_version}
sed \
  -e "s/SHPC_NAME/${shpc_name}/g" \
  -e "s/SHPC_VERSION/${shpc_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  -e "s/SINGULARITY_VERSION/${singularity_version}/g" \
  -e "s/DATE_TAG/${date_tag}/g" \
  -e "s/PYTHON_MAJORMINOR/${python_version_major}.${python_version_minor}/g" \
 pawsey-spack-config/setonix/setup/module_${shpc_name}.lua \
 > ${root_dir}/${pawsey_modules_dir}/${shpc_name}/${shpc_version}/module.lua
