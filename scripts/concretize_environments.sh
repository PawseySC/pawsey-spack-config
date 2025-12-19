#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load cpe/25.03
module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
module load gcc-native/${gcc_version}
# swap is needed for the pawsey_temp module to work
#module swap PrgEnv-gnu PrgEnv-cray
#module swap PrgEnv-cray PrgEnv-gnu
module use ${INSTALL_PREFIX}/modules/${mainarch}/gcc/${gcc_version}/programming-languages
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

