#!/bin/bash

# only editing typically needed: spack version
spack_version="0.17.0"

# TODO: needed?
# ensure starting from a new .spack
if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )
fi
mkdir ~/.spack

# get spack and its config from github
git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout v${spack_version}
cd ..

# copy configs into spack tree
cp -p pawsey-spack-config/setonix/personal_setup/*.yaml spack/etc/spack/

# apply fixes into spack tree
# Marco,s Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Pascal,s enhancements to modulefiles
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch
