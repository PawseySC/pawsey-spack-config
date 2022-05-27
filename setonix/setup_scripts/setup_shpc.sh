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
fi
# use PrgEnv-gnu and gcc version used to build python
module swap PrgEnv-cray PrgEnv-gnu
module swap gcc gcc/${gcc_version}

# load needed python toolkit
module load $python_name/$python_version
module load py-setuptools/$setuptools_version
module load py-pip/$pip_version

# create and enter install directory
cd ${root_dir}
mkdir -p ${shpc_install_dir}
cd ${shpc_install_dir}

# pip install package
sg $PAWSEY_PROJECT -c "pip install --prefix=$(pwd) singularity-hpc==$shpc_version"

# get registry from github repo
git clone https://github.com/singularityhub/singularity-hpc
cd singularity-hpc
# checkout registry, too, for reproducibility
git checkout $shpc_version
cd ..
mv singularity-hpc/registry .
# do not need rest of github repo
rm -fr singularity-hpc

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/spython

# apply patch to add SINGULARITY_SIF in lua modulefiles
patch lib/python${python_version_major}.${python_version_minor}/site-packages/shpc/main/modules/templates/singularity.lua ${root_dir}/pawsey-spack-config/setonix/fixes/shpc_sif_shell_variable.patch

# need to configure shpc for use, to change configs
export PATH=$(pwd)/bin:$PATH
export PYTHONPATH=$(pwd)/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

# back to root_dir
cd ${root_dir}

#### ALL SHPC CONFIG COMMANDS HERE
# in alternative, we could provide edited yamls, just to copy over

## ALL USERS
# lmod for modules
shpc config set module_sys:lmod
# singularity for containers
shpc config set container_tech:singularity
# locations for registry (standard and Pawsey custom)
shpc config remove registry:\$root_dir/registry
shpc config add registry:${root_dir}/${shpc_install_dir}/registry
shpc config add registry:${root_dir}/pawsey-spack-config/setonix/shpc_registry
# user install location for modulefiles
shpc config set module_base:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/containers/modules
# disable default version for modulefiles
shpc config set default_version:false
# user install location for containers
shpc config set container_base:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/containers/sif
# singularity module
shpc config set singularity_module:${singularity_name}/${singularity_version}
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
shpc config set module_base:${root_dir}/${containers_root_dir}/${shpc_spackuser_modules_dir_long}
# system install location for containers
shpc config set container_base:${root_dir}/${shpc_containers_dir}

# edit and copy over SHPC modulefile
mkdir -p ${root_dir}/${shpc_module_dir}
sed \
  -e "s/SHPC_NAME/${shpc_name}/g" \
  -e "s/SHPC_VERSION/${shpc_version}/g" \
  -e "s;SHPC_INSTALL_DIR;${shpc_install_dir};g" \
  -e "s/GCC_VERSION/${gcc_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  -e "s/SINGULARITY_MODULEFILE/${singularity_name}\/${singularity_version}/g" \
  -e "s/DATE_TAG/${date_tag}/g" \
  -e "s/PYTHON_MAJORMINOR/${python_version_major}.${python_version_minor}/g" \
 ${script_dir}/setup_templates/module_${shpc_name}.lua \
 > ${root_dir}/${shpc_module_dir}/${shpc_version}.lua
