#!/bin/bash -e

ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${ROOT_DIR}/scripts/variables.sh"


module --ignore-cache unload pawsey_prgenv
module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}

# list of environments included in variables.sh (sourced above)
envdir="${ROOT_DIR}/systems/${SYSTEM}/environments"

for env in `ls $envdir` ; do
  echo "Concretizing env $env.."
  spack env activate ${envdir}/${env} 
  spack concretize -f
  spack env deactivate
done 
