#!/bin/bash -e

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

ROOT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${ROOT_DIR}/systems/${SYSTEM}/settings.sh"

echo "Setting up spack.."
"${ROOT_DIR}/scripts/setup_spack.sh"

echo "Running first python install"
"${ROOT_DIR}/scripts/run_first_python_install.sh"

echo "Run concretization.."
"${ROOT_DIR}/scripts/run_concretization.sh"

echo "Run install all.."
"${ROOT_DIR}/scripts/run_installation_all.sh"
