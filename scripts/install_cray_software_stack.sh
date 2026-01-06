#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

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
