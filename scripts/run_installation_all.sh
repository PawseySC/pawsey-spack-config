#!/bin/bash 

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

. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

nprocs="128"
echo "Running installation with $nprocs cores.."


for env in $env_list; do
  echo "Installing environment $env..."
  cd ${envdir}/${env}
  spack env activate ${envdir}/${env} 
  spack concretize -f
  if [ "${env}" == "env_roms" ] || [ "${env}" == "env_wrf" ] ; then
    sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs} --only dependencies"
  else
    sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs}"
  fi
  spack env deactivate
  cd -
done
