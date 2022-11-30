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

. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

for env in `ls $envdir` ; do
  echo "Concretizing env $env.."
  spack env activate ${envdir}/${env} 
  spack concretize -f
  spack env deactivate
done 
