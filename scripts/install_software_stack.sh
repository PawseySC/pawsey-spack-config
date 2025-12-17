#!/bin/bash -e
# This script installs the Pawsey software stack using Spack.
# It assumes that the environment variables SYSTEM and INSTALL_PREFIX are set.
# If not, it will try to infer them from PAWSEY_CLUSTER and BASE_INSTALL_DIR.
# The script will install Spack, Python, Reframe, and various software environments.
# It will also run concretization tests and create custom Singularity modules.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

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
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"

echo "Installing shpc..."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc.sh"

echo "Installing containers.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc_containers.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
