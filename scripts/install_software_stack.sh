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
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_spack.sh"

echo "Running first python install"
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_python.sh"

echo "Run concretization.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/concretize_environments.sh"

echo "Install environments.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_environments.sh"

echo "Update singularity modules.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/update_singularity_pawsey_modules.sh"

echo "Installing shpc..."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc.sh"

echo "Installing containers.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc_containers.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
