#!/bin/bash

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
git checkout v${spack_version}
cd ..

# copy configs into spack tree
cp -p pawsey-spack-config/setonix/configs/site_allusers/*.yaml spack/etc/spack/
cp -p pawsey-spack-config/setonix/configs/spackuser_pawseystaff/*.yaml ~/.spack/
# edit DATE_TAG in config files
sed -i "s/DATE_TAG/$date_tag/g" spack/etc/spack/*.yaml ~/.spack/*.yaml

# apply fixes into spack tree
# Pascal,s fix for Zen3 on Joey, not needed on Setonix
#cp -p pawsey-spack-config/setonix/fixes/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
# Marco,s Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Pascal,s enhancements to modulefiles
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch

# TODO: copy license-protected patches/files in appropriate location, change group ownership of their directory


# edit and copy over Spack modulefile
mkdir -p ${root_dir}/${pawsey_modules_dir}/spack/${spack_version}
sed \
  -e "s/SPACK_VERSION/${spack_version}/g" \
  -e "s/PYTHON_MODULEFILE/${python_name}\/${python_version}/g" \
  -e "s/DATE_TAG/${date_tag}/g" \
  pawsey-spack-config/setonix/setup/module_spack.lua \
  > ${root_dir}/${pawsey_modules_dir}/spack/${spack_version}/module.lua
