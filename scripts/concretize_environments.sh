#!/bin/bash -e

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module use ${INSTALL_PREFIX}/modules/zen3/gcc/13.3.0/programming-languages
module load spack/${spack_version}

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

for env in $env_list ; do
  echo "Concretizing env $env.."
  spack env activate ${envdir}/${env} 
  spack concretize -f
  spack env deactivate
done

#echo "Concretizing env rocm.."
#spack env activate ${envdir}/rocm
#spack concretize -f
#spack env deactivate


for env in $cray_env_list ; do
  echo "Concretizing env $env.."
  spack env activate ${envdir}/${env}
  spack concretize -f
  spack env deactivate
done

