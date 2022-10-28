#!/bin/bash -e

# As a prerequisite, you'll have to create the installation directory,
#
#   mkdir -p $top_root_dir
#
# and clone the pawsey-spack-config repo in it. Then you can execute this script.

export top_root_dir="/software/projects/director2183/cdipietrantonio/setonixtrial"

. variables.sh

# ./setup_spack.sh ${date_tag}

# ./run_first_python_install.sh

module unload pawsey_prgenv
module use ${top_root_dir}/${date_tag}/pawsey_temp
# we need the python module to be available in order to run spack
module use ${top_root_dir}/${date_tag}/modules/zen3/gcc/12.1.0/programming-languages
module load pawsey_temp
module load spack/0.17.0
# ./run_concretization.sh

./run_installation_all.sh