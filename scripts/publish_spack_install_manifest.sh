#!/bin/bash -e
# Generate the managed module tree and complete selected-deployment inventory.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"
set_spack_config_repo
check_installation_environment
set_compilation_sets_for_arch
set_modulepaths_for_arch
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

if [ "${SYSTEM}" != "setonix-q" ] && [ "${SYSTEM}" != "ella" ]; then
  echo "Deployment inventories are enabled for setonix-q and ella."
  exit 1
fi

manifest_args=(
  publish --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}"
  --manifest "${SPACK_INSTALL_MANIFEST}"
)
if [ "$#" -gt 0 ]; then
  manifest_args+=(--environment "${bootstrap_environment}")
  for env in "$@"; do
    [ "${env}" = "${bootstrap_environment}" ] || manifest_args+=(--environment "${env}")
  done
fi
export module_cat_list
spack -E python "$(spack_install_manifest_tool)" "${manifest_args[@]}"
