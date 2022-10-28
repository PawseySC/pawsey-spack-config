#!/bin/bash -e

# need to provide DATE_TAG as arg
if [ "$#" -eq 0 ] ; then
  echo "An argument is required, providing the installation DATE_TAG."
  echo "The typical format is \"YYYY.MM\", e.g. \"2022.01\"."
  echo "Exiting now."
  exit 1
else
  new_date_tag="$1"
fi


# protecting from accidental installations
echo "Do you want to install Spack on this system? (yes/no)"
read install_answer
if [ ${install_answer,,} != "yes" ] ; then
  echo "Exiting."
  exit
else


# test that repo location and provided DATE_TAG are consistent with installation
present_script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
present_root_dir="${present_script_dir%/pawsey-spack-config*}"
eval $( echo $( grep 'top_root_dir=' ${present_script_dir}/variables.sh ) )
new_root_dir="${top_root_dir}/${new_date_tag}"
if [ "${present_root_dir}" != "${new_root_dir}" ] ; then
  echo "You are willing to deploy this installation in: ${new_root_dir}"
  echo "However, you are running from: ${present_root_dir}"
  echo "Please make sure to clone this repo in the right location, e.g.:"
  echo "  mkdir -p ${new_root_dir}"
  echo "  cd ${new_root_dir}"
  echo "  git clone https://github.com/pawseysc/pawsey-spack-config"
  echo "Exiting."
  exit 1
else
  root_dir="${new_root_dir}"
  # make sure pawsey-spack-config is in the appropriate DATE_TAG branch
  cd ${root_dir}/pawsey-spack-config
  # echo `pwd`
  # branch_exist=$( git rev-parse --quiet --verify ${new_date_tag} &>/dev/null ; echo $? )
  # if [ "${branch_exist}" == "0" ] ; then
  #   git checkout ${new_date_tag}
  # else
  #   git checkout -b ${new_date_tag}
  # fi
  cd -
  # updating date_tag in variables.sh
  sed -i "s;date_tag=.*;date_tag=\"${new_date_tag}\";g" \
    ${present_script_dir}/variables.sh
  echo "Deploying the installation in: ${present_root_dir}."
fi

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# ensure starting from a new .spack
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir ~/.spack

# get spack and its config from github
# now assuming that pawsey-spack-config is cloned beforehand
#git clone https://github.com/pawseysc/pawsey-spack-config \
#  ${root_dir}/pawsey-spack-config
[ -e ${root_dir}/spack ] || git clone https://github.com/pawseysc/spack \
  ${root_dir}/spack
cd ${root_dir}/spack
git checkout v${spack_version}
cd -

# sync configs from pawsey-spack-config onto spack tree
bash "${script_dir}/update_spack_configs_from_pawseyspackconfig.sh"

# edit DATE_TAG in sourceable script with spack functions
sed -i "s;date_tag=.*;date_tag=\"${date_tag}\" # DATE_TAG;g" \
  ${script_dir}/source_pawsey_spack_cmds.sh

# apply fixes into spack tree
# Marco,s Lmod arch family fix for the module tree
if ! [ -e ${root_dir}/spack/.patch_applied ]; then
  patch ${root_dir}/spack/lib/spack/spack/modules/lmod.py \
    ${root_dir}/pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
  # Pascal,s enhancements to modulefiles
  patch ${root_dir}/spack/lib/spack/spack/modules/common.py \
    ${root_dir}/pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
  patch ${root_dir}/spack/lib/spack/spack/cmd/modules/__init__.py \
    ${root_dir}/pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch
  touch ${root_dir}/spack/.patch_applied
fi
# create base directories for Pawsey custom builds and Pawsey utilities
mkdir -p ${root_dir}/${custom_modules_dir}
mkdir -p ${root_dir}/${custom_software_dir}
mkdir -p ${root_dir}/${utilities_modules_dir}
mkdir -p ${root_dir}/${utilities_software_dir}

# create backbone of module directories
bash "${script_dir}/update_create_system_moduletree.sh"

sed -i "s|SOFTWARESTACK_ROOT_DIR|$root_dir|g" ${script_dir}/setup_templates/*

# copy over utility scripts
sed \
  -e "s;GCC_VERSION;${gcc_version};g" \
  -e "s;AOCC_VERSION;${aocc_version};g" \
  -e "s;CCE_VERSION;${cce_version};g" \
  -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
  -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
  -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
  -e "s;R_VERSION_MAJORMINOR;${r_version_majorminor};g" \
  ${script_dir}/setup_templates/spack_create_user_moduletree.sh \
  >${root_dir}/spack/bin/spack_create_user_moduletree.sh
#
cp -p \
  ${script_dir}/setup_templates/spack_refresh_modules.sh \
  ${script_dir}/setup_templates/spack_rm_modules.sh \
  ${root_dir}/spack/bin/
sed \
  -e "s;ROOT_DIR;${root_dir};g" \
  ${script_dir}/setup_templates/spack_project.sh \
  >${root_dir}/spack/bin/spack_project.sh
chmod a+rx \
  ${root_dir}/spack/bin/spack_create_user_moduletree.sh \
  ${root_dir}/spack/bin/spack_refresh_modules.sh \
  ${root_dir}/spack/bin/spack_rm_modules.sh \
  ${root_dir}/spack/bin/spack_project.sh

# edit and copy over Spack modulefile
mkdir -p ${root_dir}/${spack_module_dir}
sed \
  -e "s/SPACK_VERSION/${spack_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  -e "s/DATE_TAG/${date_tag}/g" \
  ${script_dir}/setup_templates/module_spack.lua \
  > ${root_dir}/${spack_module_dir}/${spack_version}.lua

# create a template for the pawsey module, inside ${root_dir},
# containing the software stack related snippet,
# to be handed over to the Platforms team
module_lua_cat_list=""
for mod_cat in $module_cat_list ; do
  module_lua_cat_list+="\"$mod_cat\", "
done
sed \
  -e "s;DATE_TAG;current;g" \
  -e "s;TOP_ROOT_DIR;${top_root_dir};g" \
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
  ${script_dir}/setup_templates/module_pawsey_load_first.lua \
  > ${root_dir}/pawsey_load_first.lua

# also create a temporary pawsey module for internal Pawsey use
mkdir -p ${root_dir}/${pawsey_temp}
sed \
  -e "s;DATE_TAG;${date_tag};g" \
  -e "s;TOP_ROOT_DIR;${top_root_dir};g" \
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
  ${script_dir}/setup_templates/module_pawsey_load_first.lua \
  > ${root_dir}/${pawsey_temp}/${pawsey_temp}.lua


# protecting from accidental installations
fi
