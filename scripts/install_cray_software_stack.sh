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

echo "Run concretization.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/concretize_environments.sh"

echo "Run reframe concretization tests.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_rfm_concretization_tests.sh"

echo "Install environments.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_cray_environments.sh"

echo "Run reframe package installation tests.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_rfm_module_tests.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
