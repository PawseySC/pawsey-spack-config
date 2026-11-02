#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

echo "Run concretization.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/concretize_rocm_environment.sh"

echo "Install rocm environment.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_rocm_environment.sh"
