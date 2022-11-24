#!/bin/bash -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${SCRIPT_DIR}/variables.sh"


# ensure starting from a new .spack
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir ~/.spack

if ! [ -e ${INSTALL_PREFIX}/spack ]; then
  git clone https://github.com/pawseysc/spack ${INSTALL_PREFIX}/spack
  cd "${INSTALL_PREFIX}/spack"
  git checkout v${SPACK_VERSION}
  cd -
fi

# sync configs from pawsey-spack-config onto spack tree
cp ${SCRIPT_DIR}/../configs/site_allusers/*.yaml \
  ${INSTALL_PREFIX}/spack/etc/spack/
cp ${SCRIPT_DIR}/../configs/spackuser_pawseystaff/*.yaml ~/.spack/

# copy project-wide configs into spack tree, too
mkdir -p ${INSTALL_PREFIX}/spack/etc/spack/project_allusers
cp ${SCRIPT_DIR}/../configs/project_allusers/*.yaml \
  ${INSTALL_PREFIX}/spack/etc/spack/project_allusers/


sed -i "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
  ${INSTALL_PREFIX}/spack/etc/spack/*.yaml \
  ~/.spack/*.yaml \
  ${INSTALL_PREFIX}/spack/etc/spack/project_allusers/*.yaml


# apply Marco's LMOD fixes into spack tree
if ! [ -e ${INSTALL_PREFIX}/spack/.patch_applied ]; then
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/lmod.py \
    ${SCRIPT_DIR}/../fixes/lmod_arch_family.patch
  # Pascal,s enhancements to modulefiles
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/common.py \
    ${SCRIPT_DIR}/../fixes/modulenames_plus_common.patch
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/cmd/modules/__init__.py \
    ${SCRIPT_DIR}/../fixes/modulenames_plus_init.patch
  touch ${INSTALL_PREFIX}/spack/.patch_applied
fi

# create base directories for Pawsey custom builds and Pawsey utilities
mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${custom_software_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_software_dir}

# create backbone of module directories
bash "${SCRIPT_DIR}/update_create_system_moduletree.sh"

# sed -i "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" ${SCRIPT_DIR}/setup_templates/*

# copy over utility scripts
sed \
  -e "s;GCC_VERSION;${gcc_version};g" \
  -e "s;AOCC_VERSION;${aocc_version};g" \
  -e "s;CCE_VERSION;${cce_version};g" \
  -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
  -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
  -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
  -e "s;R_VERSION_MAJORMINOR;${r_version_majorminor};g" \
  ${SCRIPT_DIR}/setup_templates/spack_create_user_moduletree.sh \
  >${INSTALL_PREFIX}/spack/bin/spack_create_user_moduletree.sh
#
cp ${SCRIPT_DIR}/setup_templates/spack_refresh_modules.sh \
   ${SCRIPT_DIR}/setup_templates/spack_rm_modules.sh \
   ${INSTALL_PREFIX}/spack/bin/

sed \
  -e "s;INSTALL_PREFIX;${INSTALL_PREFIX};g" \
  ${SCRIPT_DIR}/setup_templates/spack_project.sh \
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
  ${SCRIPT_DIR}/setup_templates/module_spack.lua \
  > ${INSTALL_PREFIX}/${spack_module_dir}/${spack_version}.lua

# create a template for the pawsey module, inside ${INSTALL_PREFIX},
# containing the software stack related snippet,
# to be handed over to the Platforms team
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
  ${SCRIPT_DIR}/setup_templates/module_pawsey_load_first.lua \
  > ${INSTALL_PREFIX}/pawsey_load_first.lua

# also create a temporary pawsey module for internal Pawsey use
mkdir -p ${INSTALL_PREFIX}/${pawsey_temp}
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
  ${SCRIPT_DIR}/setup_templates/module_pawsey_load_first.lua \
  > ${INSTALL_PREFIX}/${pawsey_temp}/${pawsey_temp}.lua


