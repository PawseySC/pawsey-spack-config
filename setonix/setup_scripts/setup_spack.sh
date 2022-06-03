#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# TODO: needed?
# ensure starting from a new .spack
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir ~/.spack

# get spack and its config from github
cd ${root_dir}
git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout v${spack_version}
cd ..

# copy configs into spack tree
cp -p pawsey-spack-config/setonix/configs/site_allusers/*.yaml spack/etc/spack/
cp -p pawsey-spack-config/setonix/configs/spackuser_pawseystaff/*.yaml ~/.spack/
# edit DATE_TAG in config files
sed -i "s/DATE_TAG/$date_tag/g" spack/etc/spack/*.yaml ~/.spack/*.yaml

# edit DATE_TAG in sourceable script with spack functions
sed -i "s;date_tag=.*;date_tag=${date_tag} # DATE_TAG;g" pawsey-spack-config/setonix/setup_scripts/source_pawsey_spack_cmds.sh

# apply fixes into spack tree
# Marco,s Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Pascal,s enhancements to modulefiles
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch

# create backbone for Pawsey custom builds and Pawsey utilities
cd ${root_dir}
mkdir -p ${custom_modules_dir}
mkdir -p ${custom_software_dir}
mkdir -p ${utilities_modules_dir}
mkdir -p ${utilities_software_dir}

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
cd ${root_dir}
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
  ${script_dir}/setup_templates/module_pawsey_load_first.lua \
  > ${root_dir}/${pawsey_temp}/${pawsey_temp}.lua
