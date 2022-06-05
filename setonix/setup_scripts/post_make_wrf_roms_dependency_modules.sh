#!/bin/bash

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


# create destination directory
custom_full_modules_dir_zen3_gcc="${root_dir}/${custom_modules_dir}/zen3/gcc/${gcc_version}/${custom_modules_suffix}"
mkdir -p ${custom_full_modules_dir_zen3_gcc}

# wrf dependency module
./make_metamoduledependencies.sh wrf ../environments/env_wrf ${custom_full_modules_dir_zen3_gcc}

# roms dependency module
./make_metamoduledependencies.sh roms ../environments/env_roms ${custom_full_modules_dir_zen3_gcc}
