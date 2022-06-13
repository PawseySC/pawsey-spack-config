#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# copy configs into spack tree
cp -p \
  ${root_dir}/pawsey-spack-config/setonix/configs/site_allusers/*.yaml \
  ${root_dir}/spack/etc/spack/
cp -p \
  ${root_dir}/pawsey-spack-config/setonix/configs/spackuser_pawseystaff/*.yaml \
  ~/.spack/
# copy project-wide configs into spack tree, too
mkdir -p ${root_dir}/spack/etc/spack/project_allusers
cp -p \
  ${root_dir}/pawsey-spack-config/setonix/configs/project_allusers/*.yaml \
  ${root_dir}/spack/etc/spack/project_allusers/

# edit DATE_TAG in config files
sed -i "s/DATE_TAG/$date_tag/g" \
  ${root_dir}/spack/etc/spack/*.yaml \
  ~/.spack/*.yaml \
  ${root_dir}/spack/etc/spack/project_allusers/*.yaml
