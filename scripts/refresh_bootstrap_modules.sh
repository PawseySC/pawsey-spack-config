#!/bin/bash -e
# Publish only bootstrap modules before application concretization.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"
set_spack_config_repo
check_installation_environment
if [ "${SYSTEM}" = "ella" ]; then
  resolve_compatible_python_interpreter "${SPACK_PYTHON:-${BOOTSTRAP_PYTHON}}"
else
  resolve_compatible_python_interpreter
fi
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"
export module_cat_list
spack -E python "$(spack_install_manifest_tool)" publish --modules-only \
  --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}" \
  --manifest "${SPACK_INSTALL_MANIFEST}" \
  --environment "${bootstrap_environment}"
