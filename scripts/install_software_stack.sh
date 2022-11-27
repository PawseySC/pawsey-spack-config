#!/bin/bash -e

ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${ROOT_DIR}/scripts/variables.sh"

echo "Setting up spack.."
"${ROOT_DIR}/scripts/setup_spack.sh"

echo "Running first python install"
"${ROOT_DIR}/scripts/run_first_python_install.sh"

module --ignore-cache unload pawsey_prgenv
module use ${INSTALL_PREFIX}/pawsey_temp
# we need the python module to be available in order to run spack
module use ${top_root_dir}/${date_tag}/modules/zen3/gcc/12.1.0/programming-languages
module --ignore-cache load pawsey_temp
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}

echo "Run concretization.."
./run_concretization.sh

echo "Run install all.."
./run_installation_all.sh

