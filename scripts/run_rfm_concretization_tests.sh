#!/bin/bash

# This script runs Reframe tests across ALL environments to check that concretization was successful

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

# These need to be exported to be visible within Reframe
export PAWSEY_SPACK_CONFIG_REPO=${PAWSEY_SPACK_CONFIG_REPO}
export cce_version=${cce_version}
export gcc_version=${gcc_version}
export python_version=${python_version}
export reframe_version=${reframe_version}

mkdir -p "${RFM_STORAGE_DIR}"

# If running on compute node, Add node this job is running on to host list of ReFrame, allowing it to run from this node
hn=$(hostname)
if [[ $hn == *"nid"* ]]; then
    sed -i "s/\(hostnames.*setonix-01.*\).*\(\]\)/\1,'${SLURM_JOB_NODELIST}'\2/" ${RFM_SETTINGS_FILE}
fi

# Reframe testing for concretization
module load reframe/${reframe_version}
for env in $env_list; do
  echo "Running ReFrame tests for concretization in env $env"
  export SPACK_ENV=${env}
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_conc_report_${env}.json -t concretization -r
  unset SPACK_ENV
  mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_conc.out
  mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_conc.log
done

for env in $cray_env_list; do
  echo "Running ReFrame tests for concretization in env $env"
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
