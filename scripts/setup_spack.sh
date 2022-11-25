#!/bin/bash -e
# 
# Install Spack on a supercomputing system.
# 
ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )

if [ -z ${INSTALL_PREFIX+x} ]; then
    echo "The 'INSTALL_PREFIX' variable is not set. Please specify the installation
    path for the software stack being built."
    exit 1
fi

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
  SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

. "${ROOT_DIR}/scripts/variables.sh"

# The ~/.spack directory for the 'spack' user dictates where and how the system-wide
# software stack installation takes place. We must make sure that current settings
# are used instead of old ones. 
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir ~/.spack

# We will use the Pawsey spack mirror, to which several patches will be applied.
if ! [ -e ${INSTALL_PREFIX}/spack ]; then
  git clone https://github.com/pawseysc/spack ${INSTALL_PREFIX}/spack
  cd "${INSTALL_PREFIX}/spack"
  git checkout v${SPACK_VERSION}

  # apply Marco's LMOD fixes into spack tree
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/lmod.py \
    ${ROOT_DIR}/fixes/lmod_arch_family.patch
  # Pascal's enhancements to modulefiles
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/common.py \
    ${ROOT_DIR}/fixes/modulenames_plus_common.patch
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/cmd/modules/__init__.py \
    ${ROOT_DIR}/fixes/modulenames_plus_init.patch
  cd -
fi

# Next we will overwrite/create spack configuration files that rule the installation
# process for both the Pawsey staff installations (spack user), and the user and 
# project-wide ones.
cp ${ROOT_DIR}/systems/${SYSTEM}/configs/site/*.yaml ${INSTALL_PREFIX}/spack/etc/spack/
cp ${ROOT_DIR}/systems/${SYSTEM}/configs/spackuser/*.yaml ~/.spack/

# copy project-wide configs into spack tree, too
mkdir -p ${INSTALL_PREFIX}/spack/etc/spack/project
cp ${ROOT_DIR}/systems/${SYSTEM}/configs/project/*.yaml ${INSTALL_PREFIX}/spack/etc/spack/project/

# and finally customise them with the actual software stack installation path.
sed -i "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
  ${INSTALL_PREFIX}/spack/etc/spack/*.yaml \
  ~/.spack/*.yaml \
  ${INSTALL_PREFIX}/spack/etc/spack/project/*.yaml


# Instantiate utility scripts and copy them within the spack installation directory.

# spack_create_user_moduletree.sh: as the name says, the following script is used to create a user module tree directory.
sed \
  -e "s;GCC_VERSION;${gcc_version};g" \
  -e "s;AOCC_VERSION;${aocc_version};g" \
  -e "s;CCE_VERSION;${cce_version};g" \
  -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
  -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
  -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
  -e "s;R_VERSION_MAJORMINOR;${r_version_majorminor};g" \
  ${ROOT_DIR}/scripts/templates/spack_create_user_moduletree.sh \
  >${INSTALL_PREFIX}/spack/bin/spack_create_user_moduletree.sh


cp ${ROOT_DIR}/scripts/templates/spack_refresh_modules.sh \
   ${ROOT_DIR}/scripts/templates/spack_rm_modules.sh \
   ${INSTALL_PREFIX}/spack/bin/

# spack_project.sh: install a software for the entire project.
sed \
  -e "s;INSTALL_PREFIX;${INSTALL_PREFIX};g" \
  ${ROOT_DIR}/scripts/templates/spack_project.sh \
  >${INSTALL_PREFIX}/spack/bin/spack_project.sh

chmod a+rx \
  ${INSTALL_PREFIX}/spack/bin/spack_create_user_moduletree.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_refresh_modules.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_rm_modules.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_project.sh

# edit and copy over Spack modulefile
mkdir -p ${INSTALL_PREFIX}/${spack_module_dir}
sed \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g"\
  -e "s/SPACK_VERSION/${spack_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  ${ROOT_DIR}/scripts/templates/spack.lua \
  > ${INSTALL_PREFIX}/${spack_module_dir}/${spack_version}.lua


# create base directories for Pawsey custom builds and Pawsey utilities
mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${custom_software_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_software_dir}

# create backbone of module directories
"./${ROOT_DIR}/scripts/update_create_system_moduletree.sh"


# create a template for the pawsey module, inside ${INSTALL_PREFIX},
# containing the software stack related snippet, to be handed over to the Platforms team
mkdir -p "${INSTALL_PREFIX}/staff_modulefiles/pawseyenv/"
module_lua_cat_list=""
for mod_cat in $module_cat_list ; do
  module_lua_cat_list+="\"$mod_cat\", "
done

sed \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g"\
  -e "s;CUSTOM_MODULES_DIR;${custom_modules_dir};g" \
  -e "s;UTILITIES_MODULES_DIR;${utilities_modules_dir};g" \
  -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
  -e "s;CUSTOM_MODULES_SUFFIX;${custom_modules_suffix};g" \
  -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
  -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
  -e "s;GCC_VERSION;${gcc_version};g" \
  -e "s;CCE_VERSION;${cce_version};g" \
  -e "s;AOCC_VERSION;${aocc_version};g" \
  -e "s;MODULE_LUA_CAT_LIST;${module_lua_cat_list};g" \
  ${ROOT_DIR}/scripts/templates/pawseyenv.lua \
  > "${INSTALL_PREFIX}/staff_modulefiles/pawseyenv/${pawseyenv_version}.lua"