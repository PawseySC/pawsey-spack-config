#!/bin/bash -e

export top_root_dir="${MYSOFTWARE}/setonixtrial"

. variables.sh

./setup_spack.sh ${date_tag}

./run_first_python_install.sh

module unload pawsey_prgenv
module use ${top_root_dir}/${date_tag}/pawsey_temp
module load pawsey_temp
module load spack/0.17.0

./run_concretization.sh