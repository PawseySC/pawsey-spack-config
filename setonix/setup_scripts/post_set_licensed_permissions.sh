#!/bin/bash

# setting appropriate groups permissions for licensed software
# doing it one by one

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# for provisional setup (no spack modulepaths yet)
is_avail_spack="$( module is-avail spack/${spack_version} ; echo "$?" )"
if [ "${is_avail_spack}" != "0" ] ; then
  module use ${root_dir}/${pawsey_temp}
  module load ${pawsey_temp}
  module swap PrgEnv-gnu PrgEnv-cray
  module swap PrgEnv-cray PrgEnv-gnu
  module swap gcc gcc/${gcc_version}
fi
# spack module
is_loaded_spack="$( module is-loaded spack/${spack_version} ; echo "$?" )"
if [ "${is_loaded_spack}" != "0" ] ; then
  module load spack/${spack_version}
fi

# utility functions
function get_spack_install_paths()
{
  local package="$1"
  spack find -p $package |grep ^${package} |tr -s ' ' |cut -d ' ' -f 2
}

function apply_permissions()
{
  local group="$1"
  local dirs="$2"
  for dir in ${dirs} ; do
    chgrp -R ${group} $dir
  done
}


# dictionary for licensed packages and corresponding ldap groups
declare -A group
group["amber"]="amber"
# TODO: check that ANSYS package names are correct
group["cfx"]="ANSYS"
# TODO: check that ANSYS package names are correct
group["fluent"]="ANSYS"
group["cpmd"]="cpmd"
group["namd"]="namd"
group["vasp@5"]="vasp"
group["vasp@6"]="vasp6"


# Spack installations
# TODO: where are ANSYS going to be?
for package in amber cpmd namd vasp@5 vasp@6 ; do
  software_dirs=$( get_spack_install_paths $package )
  if [ "${package}" == "vasp@6" ] ; then
    module_dir="${root_dir}/modules/zen3/gcc/${gcc_version}/applications/vasp6"
  elif [ "${package}" == "vasp@5" ] ; then
    module_dir="${root_dir}/modules/zen3/gcc/${gcc_version}/applications/vasp"
  else
    module_dir="${root_dir}/modules/zen3/gcc/${gcc_version}/applications/${package}"
  fi
  apply_permissions "${group["$package"]}" "${software_dirs} ${module_dir}"
done


# Non-Spack installations
# TODO: where are ANSYS going to be?
#for package in cfx fluent ; do
#  dirs="
#  ${root_dir}/${custom_software_dir}/zen3/gcc/${gcc_version}/${package}
#  ${root_dir}/${custom_modules_dir}/zen3/gcc/${gcc_version}/${custom_modules_suffix}/${package}
#  "
#  apply_permissions "${group["$package"]}" "${dirs}"
#done
