#!/bin/bash

## DRAFT - in progress
# typically does not need any editing

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# TODO: needed?
# ensure starting from a new .spack
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$(date -Iminutes)
fi
mkdir ~/.spack

# get spack and its config from github
cd ${root_dir}
git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout ${spack_version}
cd ..

# copy configs into spack tree
cp -p pawsey-spack-config/setonix/configs_site_allusers/*.yaml spack/etc/spack/
cp -p pawsey-spack-config/setonix/configs_spackuser_pawseystaff/*.yaml ~/.spack/

# apply fixes into spack tree
cp -p pawsey-spack-config/setonix/fixes/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
# Marco,s Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Pascal,s enhancements to modulefiles
patch lib/spack/spack/modules/common.py modulenames_plus_common.patch
patch lib/spack/spack/cmd/modules/__init__.py modulenames_plus_init.patch

# TODO: use $date_tag above to update across the spack yamls
