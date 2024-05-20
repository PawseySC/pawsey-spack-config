#!/bin/bash

# This script runs Reframe tests across ALL environments to check that concretization was successful


if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

# Set to repo of deployed stack (otherwise hashes of some packages may not match)
PAWSEY_SPACK_CONFIG_REPO=/software/projects/pawsey0001/spack/2024.05_deployment/pawsey-spack-config
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}

# These need to be exported to be visible within Reframe
export PAWSEY_SPACK_CONFIG_REPO=${PAWSEY_SPACK_CONFIG_REPO}
export cce_version=${cce_version}
export gcc_version=${gcc_version}
export python_version=${python_version}
export reframe_version=3.12.0

test_repo_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
export TEST_REPO_DIR=${test_repo_dir} # Needed for reframe test to access this env var
RFM_SETTINGS_FILE=${test_repo_dir}/systems/${SYSTEM}/rfm_files/rfm_settings.py
RFM_STORAGE_DIR=/scratch/pawsey0001/cmeyer/rfm_2024.05
RFM_TEST_FILE=${test_repo_dir}/systems/${SYSTEM}/rfm_files/rfm_checks.py

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
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_conc_report_${env}.json -t concretization -l -v
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