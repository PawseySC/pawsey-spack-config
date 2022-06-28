#!/bin/bash

# protecting from accidental installations
echo "Do you want to install SHPC on this system? (yes/no)"
read install_answer
if [ ${install_answer,,} != "yes" ] ; then
  echo "Exiting."
  exit
else


# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# assumes using PrgEnv-gnu
# load needed python toolkit
module load $python_name/$python_version
module load py-setuptools/${setuptools_version}-py${python_version}
module load py-pip/${pip_version}-py${python_version}

# create and enter install directory
mkdir -p ${root_dir}/${shpc_install_dir}

# pip install package
sg spack -c "pip install --prefix=${root_dir}/${shpc_install_dir} singularity-hpc==${shpc_version}"

# get registry from github repo
git clone https://github.com/singularityhub/singularity-hpc ${root_dir}/${shpc_install_dir}/singularity-hpc
# checkout registry, too, for reproducibility
cd ${root_dir}/${shpc_install_dir}/singularity-hpc
git checkout $shpc_version
cd -
mv ${root_dir}/${shpc_install_dir}/singularity-hpc/registry ${root_dir}/${shpc_install_dir}/
# do not need rest of github repo
rm -fr ${root_dir}/${shpc_install_dir}/singularity-hpc

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" ${root_dir}/${shpc_install_dir}/bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" ${root_dir}/${shpc_install_dir}/bin/spython

# apply patch (may not be needed in future versions)
# - add SINGULARITY_CONTAINER, |tool|-container in lua modulefiles
# - enable symlinks to have shorter form <tool>/<ver>.lua
patch \
  ${root_dir}/${shpc_install_dir}/lib/python${python_version_major}.${python_version_minor}/site-packages/shpc/main/modules/templates/singularity.lua \
  ${root_dir}/pawsey-spack-config/setonix/fixes/shpc_sif_variable_short_symlinks.patch

# need to configure shpc for use, to change configs
export PATH=${root_dir}/${shpc_install_dir}/bin:$PATH
export PYTHONPATH=${root_dir}/${shpc_install_dir}/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

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
shpc config add registry:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/shpc_registry
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


# protecting from accidental installations
fi
