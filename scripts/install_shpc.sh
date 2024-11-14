#!/bin/bash -e

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

module use "${INSTALL_PREFIX}/staff_modulefiles"
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu

# assumes using PrgEnv-gnu
# load needed python toolkit
module load ${python_name}/${python_version}
#module load py-setuptools/${setuptools_version}-py${python_version}
module load py-pip/${pip_version}-py${python_version}
module load singularity/${singularity_version}

# Remove previous cached config files if any
if [ -e ~/.singularity-hpc/settings.yml ]; then
    rm ~/.singularity-hpc/settings.yml
fi
if [ -e "${INSTALL_PREFIX}/containers/views/modules" ]; then
    rm "${INSTALL_PREFIX}/containers/views/modules" -rf
fi
# create and enter install directory
[ -e ${INSTALL_PREFIX}/${shpc_install_dir} ] || mkdir -p ${INSTALL_PREFIX}/${shpc_install_dir}

# pip install package
sg ${INSTALL_GROUP} -c "pip install --prefix=${INSTALL_PREFIX}/${shpc_install_dir} singularity-hpc==${shpc_version}"

# get registry from github repo
if ! [ -e "${INSTALL_PREFIX}/${shpc_install_dir}/registry" ]; then
    # get registry from github repo
    git clone https://github.com/singularityhub/shpc-registry ${INSTALL_PREFIX}/${shpc_install_dir}/registry
    # checkout registry, too, for reproducibility
    cd ${INSTALL_PREFIX}/${shpc_install_dir}/registry
    git checkout ${shpc_registry_version}
    cd -
fi

# install Pawsey registry
if ! [ -e "${INSTALL_PREFIX}/${shpc_install_dir}/pawsey_registry" ]; then
    cp -r "${PAWSEY_SPACK_CONFIG_REPO}/shpc_registry" "${INSTALL_PREFIX}/${shpc_install_dir}/pawsey_registry"
fi

# need to configure shpc for use, to change configs
export PATH="${INSTALL_PREFIX}/${shpc_install_dir}/bin":$PATH
export PYTHONPATH="${INSTALL_PREFIX}/${shpc_install_dir}/lib/python${python_version_major}.${python_version_minor}/site-packages":$PYTHONPATH

# need to create this registry directory, otherwise corresponding config command above will fail
mkdir -p ${USER_PERMANENT_FILES_PREFIX}/$PAWSEY_PROJECT/$USER/setonix/$DATE_TAG/shpc_registry

#### ALL SHPC CONFIG COMMANDS HERE
# in alternative, we could provide edited yamls, just to copy over

## ALL USERS
# lmod for modules
shpc config set module_sys:lmod
# singularity for containers
shpc config set container_tech:singularity
shpc config remove registry https://github.com/singularityhub/shpc-registry
shpc config add registry "${INSTALL_PREFIX}/${shpc_install_dir}/registry"
shpc config add registry "${INSTALL_PREFIX}/${shpc_install_dir}/pawsey_registry"
shpc config add registry "${USER_PERMANENT_FILES_PREFIX}/\$PAWSEY_PROJECT/\$USER/setonix/$DATE_TAG/shpc_registry"
# user install location for modulefiles
shpc config set "module_base:${USER_PERMANENT_FILES_PREFIX}/\$PAWSEY_PROJECT/\$USER/setonix/$DATE_TAG/${shpc_containers_modules_dir_long}"
# disable default version for modulefiles (original)
shpc config set default_version:null
# user install location for containers
shpc config set "container_base:${USER_PERMANENT_FILES_PREFIX}/\$PAWSEY_PROJECT/\$USER/setonix/$DATE_TAG/${shpc_containers_dir}"
# user install location for modulefiles (symlinks - views)
# variable substitutions assume format like views/modules
shpc config set "views_base:${USER_PERMANENT_FILES_PREFIX}/\$PAWSEY_PROJECT/\$USER/setonix/$DATE_TAG/${shpc_containers_modules_dir%/*}"
shpc config set "default_view:${shpc_containers_modules_dir##*/}"
# singularity module
shpc config set "singularity_module:${singularity_name}/${singularity_version}"
# enable wrapper scripts
shpc config set wrapper_scripts:enabled:true
shpc config set "wrapper_base:${USER_PERMANENT_FILES_PREFIX}/\$PAWSEY_PROJECT/\$USER/setonix/$DATE_TAG/containers/wrappers"
# GPU support (Phase 2)
#shpc config set container_features:gpu:amd
# enable X11 graphics
shpc config set container_features:x11:true
# location for container fake home
shpc config set "container_features:home:\$MYSOFTWARE/setonix/$DATE_TAG/.${shpc_name}_home"

## SPACK USER (system wide installation)
shpc config inituser
# system install location for modulefiles (original)
shpc config set module_base:"${INSTALL_PREFIX}/${shpc_containers_modules_dir_long}"
# system install location for containers
shpc config set "container_base:${INSTALL_PREFIX}/${shpc_containers_dir}"
# system install location for modulefiles (symlinks - views)
# variable substitutions assume format like views/modules
shpc config set "views_base:${INSTALL_PREFIX}/${shpc_containers_modules_dir%/*}"
shpc config set "default_view:${shpc_containers_modules_dir##*/}"
shpc view create "${shpc_containers_modules_dir##*/}"

# edit and copy over SHPC modulefile
mkdir -p "${INSTALL_PREFIX}/${shpc_module_dir}"
sed \
  -e "s/SHPC_NAME/${shpc_name}/g" \
  -e "s/SHPC_VERSION/${shpc_version}/g" \
  -e "s;SHPC_INSTALL_DIR;${shpc_install_dir};g" \
  -e "s/GCC_VERSION/${gcc_version}/g" \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  -e "s/SINGULARITY_MODULEFILE/${singularity_name}\/${singularity_version}/g" \
  -e "s/PYTHON_MAJORMINOR/${python_version_major}.${python_version_minor}/g" \
 "${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/${shpc_name}.lua" \
 > "${INSTALL_PREFIX}/${shpc_module_dir}/${shpc_version}.lua"
