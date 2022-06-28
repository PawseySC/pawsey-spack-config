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


# create destination directory
custom_full_modules_dir_zen3_gcc="${root_dir}/${custom_modules_dir}/zen3/gcc/${gcc_version}/${custom_modules_suffix}"
mkdir -p ${custom_full_modules_dir_zen3_gcc}

# wrf dependency module
./make_metamoduledependencies.sh wrf ${script_dir}/../environments/env_wrf ${custom_full_modules_dir_zen3_gcc}

# roms dependency module
./make_metamoduledependencies.sh roms ${script_dir}/../environments/env_roms ${custom_full_modules_dir_zen3_gcc}

# hiding wrf/roms dependency modules for now
mv ${custom_full_modules_dir_zen3_gcc}/wrf-dependency-set.lua \
  ${custom_full_modules_dir_zen3_gcc}/.wrf-dependency-set.lua
mv ${custom_full_modules_dir_zen3_gcc}/roms-dependency-set.lua \
  ${custom_full_modules_dir_zen3_gcc}/.roms-dependency-set.lua
