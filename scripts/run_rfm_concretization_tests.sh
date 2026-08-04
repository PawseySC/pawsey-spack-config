#!/bin/bash

# This script runs Reframe tests across ALL environments to check that concretization was successful

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

if [ "${SYSTEM}" = "setonix-q" ]; then
  set_modulepaths_for_arch
else
  # Preserve the Setonix module setup from main.
  module use ${INSTALL_PREFIX}/staff_modulefiles
  module --ignore-cache load pawseyenv/${pawseyenv_version}
  module load cpe/25.03
  module load gcc-native/14.2
  module load spack/${spack_version}
fi

# These need to be exported to be visible within Reframe
export PAWSEY_SPACK_CONFIG_REPO=${PAWSEY_SPACK_CONFIG_REPO}
export cce_version=${cce_version}
export gcc_version=${gcc_version}
export python_version=${python_version}
export reframe_version=${reframe_version}
export env_list
export cray_env_list

if [ "${SYSTEM}" = "setonix-q" ]; then
  # ReFrame imports installation checks before applying tag filters. Keep the
  # concretization run independent of any manifest from an earlier deployment.
  export SPACK_INSTALL_MANIFEST="${INSTALL_PREFIX}/installation_metadata/.concretization-only"
fi

mkdir -p "${RFM_STORAGE_DIR}"

function check_concretized_environment()
{
  local env="$1"
  local lock_file="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments/${env}/spack.lock"

  if [ ! -f "${lock_file}" ]; then
    echo "Missing ${lock_file}; run scripts/concretize_environments.sh before ReFrame concretization tests."
    exit 1
  fi
}

# If running on compute node, Add node this job is running on to host list of ReFrame, allowing it to run from this node
hn=$(hostname)
if [[ $hn == *"nid"* ]]; then
    sed -i "s/\(hostnames.*setonix-01.*\).*\(\]\)/\1,'${SLURM_JOB_NODELIST}'\2/" ${RFM_SETTINGS_FILE}
fi

# Reframe testing for concretization
module load reframe/${reframe_version}
for env in $env_list; do
  echo "Running ReFrame tests for concretization in env $env"
  check_concretized_environment "${env}"
  export SPACK_ENV=${env}
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_conc_report_${env}.json -t concretization -r
  unset SPACK_ENV
  mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_conc.out
  mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_conc.log
done

for env in $cray_env_list; do
  echo "Running ReFrame tests for concretization in env $env"
  check_concretized_environment "${env}"
  export SPACK_ENV=${env}
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_conc_report_${env}.json -t concretization -l -v
  unset SPACK_ENV   
  mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_conc.out
  mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_conc.log
done

# Reset valid setonix hostnames to original entries (i.e. remove the node this job runs on) for future runs
if [[ $hn == *"nid"* ]]; then
    sed -i "s/\(hostnames.*setonix-01.*\)\(,.*\]\)/\1]/" ${RFM_SETTINGS_FILE}
fi
