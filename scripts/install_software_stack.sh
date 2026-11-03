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

echo "Running first reframe install"
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_reframe.sh"

echo "Run concretization.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/concretize_environments.sh"

echo "Run reframe concretization tests.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_rfm_concretization_tests.sh"

echo "Install environments.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_environments.sh"
# Next line is not required as it is included in install_environments.sh
# "${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_cray_environments.sh"

echo "Update singularity modules.."
# note that moving forward using the singularityce recipes. Comment out the singularity_modules, kept for reference
#"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_custom_singularity_modules.sh"
# Using new wrapper: generate_singularity_modules.sh that also allows for easy regeneration of modules after installation.
# For its use here:
# --install-type official : generates modulefiles in the official deployment path
# --version all : generates modulefiles for all installed SingularityCE versions.
# --force : replaces existing modulefiles (allows reruns of this main script without needing previous manual cleanup of existing modulefiles)
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/generate_singularity_modules.sh" \
    --install-type official --version all --force

echo "Installing shpc..."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc.sh"

echo "Installing containers.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc_containers.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
