#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# spack module
is_loaded_spack="$( module is-loaded spack/${spack_version} ; echo "$?" )"
if [ "${is_loaded_spack}" != "0" ] ; then
  module load spack/${spack_version}
fi


# original environment yaml
original_env_yaml="${script_dir}/../environments/env_python/spack.yaml"
# directory to create derivative yaml for the view
view_env_dir="${script_dir}/view_python"
# name for the view
view_name="hpc-python-collection"
# target directory for view installation
view_software_root_dir="${root_dir}/${custom_software_dir}/${cpu_arch}/gcc/${gcc_version}"
view_software_dir="${view_software_root_dir}/${view_name}"
# target directory for view module
view_module_dir="${root_dir}/${custom_modules_dir}/${cpu_arch}/gcc/${gcc_version}/${custom_modules_suffix}/${view_name}"
# template for view module
view_module_template="${script_dir}/setup_templates/module_hpc_python_collection.lua"

# only proceed if original environment yaml exists
if [ -e ${original_env_yaml} ] ; then


# make sure required directories exist
mkdir -p ${view_env_dir}
mkdir -p ${view_software_root_dir}
mkdir -p ${view_module_dir}

# delete files from previous view installation
echo "You are about to delete the following items:"
echo "  ${view_env_dir}"
echo "  ${view_software_dir}"
echo "  ${view_module_dir}"
echo "Do these directories correspond to the view environment ${view_name} ?"
echo "Do you want to delete them? (yes/no)"
read view_answer
if [ ${view_answer,,} == "yes" ] ; then
  rm -rf ${view_env_dir}/spack.* ${view_env_dir}/.spack*
  rm -rf ${view_software_dir} ${view_software_root_dir}/._${view_name}
  rm -f ${view_module_dir}/*.lua
else
  echo "Skipping deletion of view directories. Stopping process to create view ${view_name} ."
  exit 1
fi

# create Spack environment with view
sed "s;  view: .*[fF]alse;  view: ${view_software_dir};g" \
  ${original_env_yaml} \
  >${view_env_dir}/spack.yaml
spack env activate -V ${view_env_dir}
spack concretize -f
# get info for the modulefile
# the grep syntax works as of spack v0.17.0
view_root_packages=$( spack find | sed -n '/Root specs/,/^$/p' | grep -v -e '^==>' -e '^--' -e '^$' | cut -d '%' -f 1 )
spack env deactivate

# create modulefile for view
view_python_version=$( echo $view_root_packages | xargs -n 1 | grep ^python@ | cut -d '@' -f 2 )
view_version="${date_tag}-py${view_python_version}"
view_python_version_major="$( echo $view_python_version | cut -d '.' -f 1 )"
view_python_version_minor="$( echo $view_python_version | cut -d '.' -f 2 )"
view_python_version_major_minor="${view_python_version_major}.${view_python_version_minor}"
sed \
  -e "s;VIEW_VERSION;${view_version};g" \
  -e "s;VIEW_ROOT_PACKAGES;$( echo ${view_root_packages} );g" \
  -e "s;VIEW_ROOT;${view_software_dir};g" \
  -e "s;VIEW_PYTHON_VERSION_MAJOR_MINOR;${view_python_version_major_minor};g" \
  ${view_module_template} \
  >${view_module_dir}/${view_version}.lua


else
  echo "Original environment yaml not found: ${original_env_yaml}"
  echo "Exiting."
  exit 1
fi
