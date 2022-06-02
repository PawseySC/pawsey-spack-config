#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || pwd)"
. ${script_dir}/variables.sh

# This script creates end user singularity modules, starting from the Spack one
# For each version:
# 1. creates 2 pawsey/modules : A. singularity, and B. singularity-astro
#    - to have Singularity available regardless the loaded PrgEng/compiler
#      (works thanks to RPATHs)
#    - to have /astro and /askapbuffer only for astronomers
# 2. hides Spack module in {spack modules}/{arch}/{compiler}
#    - to avoid confusion

# define source (Spack) and destination (Pawsey) directories for Singularity
src_dir="${root_dir}/modules/${cpu_arch}/gcc/${gcc_version}/utilities/${singularity_name}"
dst_dir="${root_dir}/${singularity_symlink_module_dir}"

# ensure destination directory exists
mkdir -p ${dst_dir}

for version in $( ls ${src_dir} ) ; do
  # 1.B singularity-astro is just the original module
  cp -p ${src_dir}/${version} ${dst_dir}/${version/\.lua/-astro.lua}
  # 1.A singularity does not bind mount /askapbuffer and /astro
  sed \
    -e '/SINGULARITY_BINDPATH/ s;/askapbuffer;;g' \
    -e '/SINGULARITY_BINDPATH/ s;/astro;;g' \
    ${dst_dir}/${version/\.lua/-astro.lua} \
    >${dst_dir}/${version}
  #2. hide Spack module
  rm -f ${src_dir}/.modulerc.lua
  echo "hide_modulefile(\"${src_dir}/${version}\")" >>${src_dir}/.modulerc.lua
  echo "hide_modulefile(\"${src_dir/${date_tag}/current}/${version}\")" >>${src_dir}/.modulerc.lua
done


