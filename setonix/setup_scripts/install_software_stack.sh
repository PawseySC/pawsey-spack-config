#!/bin/bash -e

# As a prerequisite, you'll have to create the installation directory,
#
#   mkdir -p $top_root_dir
#
# and clone the pawsey-spack-config repo in it. Then you can execute this script.

if [ -z ${top_root_dir+x} ]; then
    echo "The 'top_root_dir' variable must be set to the path where to the software stack will be installed."
    exit 1
fi

if [ -z ${INSTALL_GROUP+x} ]; then
    echo "The 'INSTALL_GROUP' variable must be set to the path where to the software stack will be installed."
    exit 1
fi

. variables.sh

./setup_spack.sh ${date_tag} 
echo "Running first python install"
./run_first_python_install.sh

module --ignore-cache unload pawsey_prgenv
module use ${top_root_dir}/${date_tag}/pawsey_temp
# we need the python module to be available in order to run spack
module use ${top_root_dir}/${date_tag}/modules/zen3/gcc/12.1.0/programming-languages
module --ignore-cache load pawsey_temp
module load spack/0.17.0

spack -d install singularity 
echo "Run concretization.."
./run_concretization.sh

echo "Run install all.."
./run_installation_all.sh
