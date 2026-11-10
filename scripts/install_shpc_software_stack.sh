#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

echo "Update singularity modules.."
# note that moving forward using the singularityce recipes. Comment out the singularity_modules, kept for reference
#"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_custom_singularity_modules.sh"
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh"

if [ "${SYSTEM}" != "setonix" ]; then
    echo "Skipping Setonix-only SHPC registry/container/post-install operations for ${SYSTEM}."
    exit 0
fi

echo "Installing shpc..."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc.sh"

echo "Installing containers.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc_containers.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
