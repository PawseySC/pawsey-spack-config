#!/bin/bash

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${ROOT_DIR}/systems/${SYSTEM}/settings.sh"

# assumes using PrgEnv-gnu
# load needed python toolkit
module load $python_name/$python_version
module load py-setuptools/${setuptools_version}-py${python_version}
module load py-pip/${pip_version}-py${python_version}

# create and enter install directory
mkdir -p ${INSTALL_PREFIX}/${shpc_install_dir}

# pip install package
sg spack -c "pip install --prefix=${INSTALL_PREFIX}/${shpc_install_dir} singularity-hpc==${shpc_version}"

# get registry from github repo
git clone https://github.com/singularityhub/singularity-hpc ${INSTALL_PREFIX}/${shpc_install_dir}/singularity-hpc
# checkout registry, too, for reproducibility
cd ${INSTALL_PREFIX}/${shpc_install_dir}/singularity-hpc
git checkout $shpc_version
cd -
mv ${INSTALL_PREFIX}/${shpc_install_dir}/singularity-hpc/registry ${INSTALL_PREFIX}/${shpc_install_dir}/
# do not need rest of github repo
rm -fr ${INSTALL_PREFIX}/${shpc_install_dir}/singularity-hpc

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" ${INSTALL_PREFIX}/${shpc_install_dir}/bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" ${INSTALL_PREFIX}/${shpc_install_dir}/bin/spython

# need to configure shpc for use, to change configs
export PATH=${INSTALL_PREFIX}/${shpc_install_dir}/bin:$PATH
export PYTHONPATH=${INSTALL_PREFIX}/${shpc_install_dir}/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

#### ALL SHPC CONFIG COMMANDS HERE
# in alternative, we could provide edited yamls, just to copy over

## ALL USERS
# lmod for modules
shpc config set module_sys:lmod
# singularity for containers
shpc config set container_tech:singularity
# locations for registry (standard and Pawsey custom)
shpc config remove registry:\$root_dir/registry
shpc config add registry:${INSTALL_PREFIX}/${shpc_install_dir}/registry
shpc config add registry:${INSTALL_PREFIX}/pawsey-spack-config/setonix/shpc_registry
shpc config add registry:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/shpc_registry
# user install location for modulefiles
shpc config set module_base:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/${shpc_containers_modules_dir_long}
# disable default version for modulefiles (original)
shpc config set default_version:null
# user install location for containers
shpc config set container_base:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/${shpc_containers_dir}
# user install location for modulefiles (symlinks - views)
# variable substitutions assume format like views/modules
shpc config set views_base:/software/projects/\$PAWSEY_PROJECT/\$USER/setonix/${shpc_containers_modules_dir%/*}
shpc config set default_view:${shpc_containers_modules_dir##*/}
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
# system install location for modulefiles (original)
shpc config set module_base:${INSTALL_PREFIX}/${shpc_containers_modules_dir_long}
# system install location for containers
shpc config set container_base:${INSTALL_PREFIX}/${shpc_containers_dir}
# system install location for modulefiles (symlinks - views)
# variable substitutions assume format like views/modules
shpc config set views_base:${INSTALL_PREFIX}/${shpc_containers_modules_dir%/*}
shpc config set default_view:${shpc_containers_modules_dir##*/}
shpc view create ${shpc_containers_modules_dir##*/}

# edit and copy over SHPC modulefile
mkdir -p ${INSTALL_PREFIX}/${shpc_module_dir}
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
 > ${INSTALL_PREFIX}/${shpc_module_dir}/${shpc_version}.lua