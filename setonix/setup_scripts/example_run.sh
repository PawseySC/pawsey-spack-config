#!/bin/bash

# for provisional setup (no spack modulepaths yet)
is_avail_spack="$( module is-avail spack/${spack_version} ; echo "$?" )"
if [ "${is_avail_spack}" != "0" ] ; then
  module use ${root_dir}/${pawsey_temp}
  module load ${pawsey_temp}
fi

module load spack/0.17.0

spack spec nano

# remember to install by forcing with your group ownership
sg $PAWSEY_PROJECT -c 'spack install nano'
