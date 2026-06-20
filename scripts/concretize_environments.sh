#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# Preserve the Setonix/x86 PrgEnv refresh used by the previous concretization
# setup. Setonix-Q gets its compiler/module setup from set_modulepaths_for_arch.
if [ "$( uname -m )" == "x86_64" ]; then
  module swap PrgEnv-gnu PrgEnv-cray
  module swap PrgEnv-cray PrgEnv-gnu
fi

set_modulepaths_for_arch

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
