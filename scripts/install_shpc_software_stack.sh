#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

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
