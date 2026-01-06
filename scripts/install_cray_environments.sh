#!/bin/bash 

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}

nprocs="128"

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

echo "Running installation with $nprocs cores.."


for env in $cray_env_list; do
  echo "Installing environment $env..."
  cd ${envdir}/${env}
  spack env activate ${envdir}/${env}
  spack concretize -f
  sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs}"
  spack env deactivate
  cd -
done

