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
cd ${INSTALL_PREFIX}
git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout ${spack_version}
cd ..

# copy configs into spack tree
cp -p pawsey-spack-config/examples/garrawarla/configs/*.yaml spack/etc/spack/

# apply fixes into spack tree

# Marco,s Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Pascal,s enhancements to modulefiles
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch

# TODO: copy license-protected patches/files in appropriate location, change group ownership of their directory

# TODO: use $date_tag above to update across the spack yamls
