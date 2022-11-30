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

echo "Setting up spack.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/setup_spack.sh"

echo "Running first python install"
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_first_python_install.sh"

echo "Run concretization.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_concretization.sh"

echo "Run install all.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_installation_all.sh"
