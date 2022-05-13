#!/bin/bash
  
# minimal script to initialise Spack on Joey for personal testing
# everything is done in the current working directory, and in the ~/.spack


if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old.$(date -Iminutes)
fi
mkdir ~/.spack

git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout v0.17.0
cd ..

# configs
cp -p pawsey-spack-config/setonix/configs/site_allusers/*.yaml spack/etc/spack/
cp -p pawsey-spack-config/setonix/configs/spackuser_pawseystaff/*.yaml ~/.spack/
# patches
cp -p pawsey-spack-config/setonix/fixes/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch

# Joey specific
# this is the date tag to be replaced in the config yamls, with the current directory
install_dir="$(pwd)"
sed -i "s;/software/setonix/DATE_TAG;$install_dir;g" spack/etc/spack/*.yaml ~/.spack/*.yaml
