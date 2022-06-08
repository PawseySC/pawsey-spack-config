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


# utility function
function apply_permissions()
{
  local group="$1"
  local dirs="$2"
  for dir in ${dirs} ; do
    chgrp -R ${group} $dir
    chmod -R o-rwx $dir
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

# list of archs/compilers to find all modulefiles
archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"

# Spack installations
# TODO: where are ANSYS going to be?
for package in amber cpmd namd vasp@5 vasp@6 ; do
  software_dirs=$( spack find -p $package |grep ^${package} |tr -s ' ' |cut -d ' ' -f 2 )
  module_dirs=""
  if [ "${package}" == "vasp@6" ] ; then
    package="vasp6"
  else
    package=${package%@*}
  fi
  for arch in $archs; do
    for compiler in $compilers; do
      add_module_dir="${root_dir}/modules/${arch}/${compiler}/applications/${package}"
      if [ -d "${add_module_dir}" ] ; then
        module_dirs+="${add_module_dir}"
      fi
    done
  done
  echo ${package^^}
  echo "${group["$package"]}"
  echo "${software_dirs}"
  echo "${module_dirs}"
  echo ""
  apply_permissions "${group["$package"]}" "${software_dirs} ${module_dirs}"
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
