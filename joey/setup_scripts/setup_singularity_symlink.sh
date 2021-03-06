#!/bin/bash

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# This script just does one thing
# It creates a symlink from {spack modules}/{arch}/{compiler}
# to the Pawsey utilities module directory
# In this way, Singularity is available regardless the loaded PrgEng/compiler
# It will still work, thanks to RPATH

src_dir="${root_dir}/modules/${cpu_arch}/gcc/${gcc_version}/utilities/${singularity_name}"
dst_dir="${root_dir}/${singularity_symlink_module_dir}"

mkdir -p ${dst_dir}

for version in $( ls ${src_dir} ) ; do
  ln -s ${src_dir}/${version} ${dst_dir}/${version}
done


