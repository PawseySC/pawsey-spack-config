#!/bin/bash -e
# ReFrame requests one exclusive node per test; no allocation pack is required.
scriptdir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "${scriptdir}/../../scripts/pawsey_software_stack_funcs.sh"

export SYSTEM=ella
set_spack_config_repo
check_installation_environment
set_modulepaths_for_arch || exit 1
module load "reframe/${reframe_version}" || exit 1
export INSTALL_PREFIX DATE_TAG gcc_version python_version reframe_version
reframe -C "${RFM_SETTINGS_FILE}" -c "${scriptdir}/rfm_files/standalone_checks.py" \
    --prefix="${RFM_STORAGE_DIR}" -r "$@"
