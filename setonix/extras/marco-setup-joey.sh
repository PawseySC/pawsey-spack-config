#!/bin/bash
  
# minimal script to initialise Spack on Joey for personal testing
# everything is done in the current working directory, and in the ~/.spack


if [ -e ~/.spack ] ; then
  mv ~/.spack ~/.spack.old
fi
mkdir ~/.spack

git clone https://github.com/pawseysc/pawsey-spack-config
git clone https://github.com/pawseysc/spack
cd spack/
git checkout v0.17.0
cd ..

cp -p pawsey-spack-config/setonix/configs_site_allusers/*.yaml spack/etc/spack/
cp -p pawsey-spack-config/setonix/configs_spackuser_pawseystaff/*.yaml ~/.spack/
cp -p pawsey-spack-config/setonix/fixes/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch

# Joey specific
sed -i '/USER/ s;^;#;g' spack/etc/spack/repos.yaml
# this is the date tag to be replaced in the config yamls, with the current directory
date_tag="2022.01"
install_dir="$(pwd)"
sed -i "s;/software/setonix/$date_tag;$install_dir;g" spack/etc/spack/*.yaml ~/.spack/*.yaml
