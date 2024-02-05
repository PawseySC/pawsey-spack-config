#!/bin/bash -e
# 
# Install Spack on a supercomputing system.
# 
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

# The $SPACK_USER_CONFIG_PATH directory for the 'spack' user dictates where and how the system-wide
# software stack installation takes place. We must make sure that current settings
# are used instead of old ones. 
if [ -e $SPACK_USER_CONFIG_PATH ]; then
  mv $SPACK_USER_CONFIG_PATH $SPACK_USER_CONFIG_PATH.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir -p ${SPACK_USER_CONFIG_PATH}

# We will use the Pawsey spack mirror, to which several patches will be applied.
if ! [ -e ${INSTALL_PREFIX}/spack ]; then
  git clone https://github.com/spack/spack.git ${INSTALL_PREFIX}/spack
#  git clone https://github.com/pawseysc/spack ${INSTALL_PREFIX}/spack
  cd "${INSTALL_PREFIX}/spack"
  git checkout v${spack_version}

  # apply Marco's LMOD fixes into spack tree
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/lmod.py \
    ${PAWSEY_SPACK_CONFIG_REPO}/fixes/lmod_arch_family.patch
  # Pascal's enhancements to modulefiles
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/modules/common.py \
    ${PAWSEY_SPACK_CONFIG_REPO}/fixes/modulenames_plus_common.patch
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/cmd/modules/__init__.py \
    ${PAWSEY_SPACK_CONFIG_REPO}/fixes/modulenames_plus_init.patch
  patch ${INSTALL_PREFIX}/spack/lib/spack/spack/paths.py \
    ${PAWSEY_SPACK_CONFIG_REPO}/fixes/dot_spack.patch
  sed -i -e "s|DATE_TAG|$DATE_TAG|g"\
    -e "s|PAWSEY_SYSTEM|$SYSTEM|g"\
    ${INSTALL_PREFIX}/spack/lib/spack/spack/paths.py
  
  rm "${INSTALL_PREFIX}/spack/.git" -rf
  cd -
fi

# Next we will overwrite/create spack configuration files that rule the installation
# process for both the Pawsey staff installations (spack user), and the user and 
# project-wide ones.
cp ${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/configs/site/*.yaml ${INSTALL_PREFIX}/spack/etc/spack/
cp ${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/configs/spackuser/*.yaml ${SPACK_USER_CONFIG_PATH}/

# copy project-wide configs into spack tree, too
mkdir -p ${INSTALL_PREFIX}/spack/etc/spack/project
cp ${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/configs/project/*.yaml ${INSTALL_PREFIX}/spack/etc/spack/project/

# Copy over custom Pawsey recipes in a spack pawsey repo within the spack installation
[ -e "${INSTALL_PREFIX}/spack/var/spack/repos/pawsey" ] || mkdir -p "${INSTALL_PREFIX}/spack/var/spack/repos/pawsey"
cp -r ${PAWSEY_SPACK_CONFIG_REPO}/repo/* "${INSTALL_PREFIX}/spack/var/spack/repos/pawsey/"

# .. and custom module templates
[ -e "${INSTALL_PREFIX}/spack/templates" ] || mkdir -p "${INSTALL_PREFIX}/spack/templates"
cp -r ${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/templates/* "${INSTALL_PREFIX}/spack/templates/"

# and finally customise them with the actual software stack installation path.
sed -i \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
  -e "s|DATE_TAG|$DATE_TAG|g"\
  -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g"\
  -e "s|USER_TEMP_FILES_PREFIX|${USER_TEMP_FILES_PREFIX}|g"\
  -e "s|BOOTSTRAP_PATH|${BOOTSTRAP_PATH}|g"\
  ${INSTALL_PREFIX}/spack/etc/spack/*.yaml \
  ${SPACK_USER_CONFIG_PATH}/*.yaml \
  ${INSTALL_PREFIX}/spack/etc/spack/project/*.yaml \
  ${INSTALL_PREFIX}/spack/templates/modules/modulefile.lua


# Instantiate utility scripts and copy them within the spack installation directory.

# spack_create_user_moduletree.sh: as the name says, the following script is used to create a user module tree directory.
sed \
  -e "s;GCC_VERSION;${gcc_version};g" \
  -e "s;AOCC_VERSION;${aocc_version};g" \
  -e "s;CCE_VERSION;${cce_version};g" \
  -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
  -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
  -e "s|DATE_TAG|$DATE_TAG|g"\
  -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
  -e "s;R_VERSION_MAJORMINOR;${r_version_majorminor};g" \
  -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g"\
  ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/spack_create_user_moduletree.sh \
  >${INSTALL_PREFIX}/spack/bin/spack_create_user_moduletree.sh


cp ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/spack_refresh_modules.sh \
   ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/spack_rm_modules.sh \
   ${PAWSEY_SPACK_CONFIG_REPO}/scripts/spack_generate_migration_scripts.sh \
   ${INSTALL_PREFIX}/spack/bin/

# Install a spack wrapper to handle project installations
if ! [ -e ${INSTALL_PREFIX}/spack/bin/realspack ]; then
  mv ${INSTALL_PREFIX}/spack/bin/spack ${INSTALL_PREFIX}/spack/bin/realspack
  sed \
    -e "s;INSTALL_PREFIX;${INSTALL_PREFIX};g" \
    ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/spack \
    >${INSTALL_PREFIX}/spack/bin/spack
fi

chmod a+rx \
  ${INSTALL_PREFIX}/spack/bin/spack_create_user_moduletree.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_refresh_modules.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_rm_modules.sh \
  ${INSTALL_PREFIX}/spack/bin/spack_generate_migration_scripts.sh \
  ${INSTALL_PREFIX}/spack/bin/spack

# edit and copy over Spack modulefile
mkdir -p ${INSTALL_PREFIX}/${spack_module_dir}
sed \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g"\
  -e "s|DATE_TAG|$DATE_TAG|g"\
  -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g"\
  -e "s/SPACK_VERSION/${spack_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/spack.lua \
  > ${INSTALL_PREFIX}/${spack_module_dir}/${spack_version}.lua


# create base directories for Pawsey custom builds and Pawsey utilities
mkdir -p ${INSTALL_PREFIX}/${custom_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${custom_software_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_modules_dir}
mkdir -p ${INSTALL_PREFIX}/${utilities_software_dir}

# create backbone of module directories
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_system_moduletree.sh"


# create a template for the pawsey module, inside ${INSTALL_PREFIX},
# containing the software stack related snippet, to be handed over to the Platforms team
mkdir -p "${INSTALL_PREFIX}/staff_modulefiles/pawseyenv/"
module_lua_cat_list=""
for mod_cat in $module_cat_list ; do
  module_lua_cat_list+="\"$mod_cat\", "
done

sed \
  -e "s|INSTALL_PREFIX|${INSTALL_PREFIX}|g"\
  -e "s|DATE_TAG|$DATE_TAG|g"\
  -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g"\
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
  ${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/pawseyenv.lua \
  > "${INSTALL_PREFIX}/staff_modulefiles/pawseyenv/${pawseyenv_version}.lua"
