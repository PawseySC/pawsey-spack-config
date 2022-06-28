#!/bin/bash

# setting appropriate groups permissions for licensed software
# doing it one by one

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

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
  if [ ! -z "$dirs" ] ; then
    for dir in ${dirs} ; do
      if [ -e "$dir" ] ; then
        chgrp -R ${group} $dir
        chmod -R o-rwx $dir
      fi
    done
  fi
}

# list of archs/compilers to find all modulefiles
archs="zen3 zen2"
compilers="gcc/${gcc_version} aocc/${aocc_version} cce/${cce_version}"

# source tarballs
lic_tar_dir="${top_root_dir}/licensed_src"
apply_permissions spack ${lic_tar_dir}

# do or skip software directories (takes about 1-2 minutes)
if [ "$1" == "only-modules" ] ; then
  only_modules="0"
  echo "Setting licensing permissions: modules only, skipping software."
else
  only_modules="1"
  echo "Setting licensing permissions: modules and software."
fi

# Spack installations
for package in amber ansys-fluids ansys-structures ansys-fluidstructures cpmd namd vasp@5 vasp@6 ; do
  software_dirs=$( spack find -p $package |grep ^${package} |tr -s ' ' |cut -d ' ' -f 2 )
  module_dirs=""
  if [ "${package}" == "vasp@6" ] ; then
    tool_module="vasp6"
  else
    tool_module=${package%@*}
  fi
  if [[ "${package}" =~ "ansys" ]] ; then
    linux_group="ANSYS"
  else
    linux_group="${tool_module}"
  fi
  for arch in $archs; do
    for compiler in $compilers; do
      add_module_dir="${root_dir}/modules/${arch}/${compiler}/applications/${tool_module}"
      if [ -d "${add_module_dir}" ] ; then
        module_dirs+="${add_module_dir}"
      fi
    done
  done
  echo "PACKAGE: ${package}"
  echo "${linux_group}"
  echo "${module_dirs}"
  if [ "${only_modules}" != "0" ] ; then
    echo "${software_dirs}"
    apply_permissions "${linux_group}" "${software_dirs} ${module_dirs}"
  else
    apply_permissions "${linux_group}" "${module_dirs}"
  fi
  echo ""
done
