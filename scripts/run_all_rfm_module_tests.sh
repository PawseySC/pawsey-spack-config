#!/bin/bash

# This script runs ALL Reframe module tests, with no exceptions

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# Add node this job is running on to host list of ReFrame, allowing it to run from this node
sed -i "s/\(hostnames.*setonix-01.*\).*\(\]\)/\1,'${SLURM_JOB_NODELIST}'\2/" ${RFM_SETTINGS_FILE}

# Reframe testing for modules
module load reframe/${reframe_version}
for env in $env_list; do
  echo "Running ReFrame tests for modules in env $env"
  export SPACK_ENV=${env}
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_install_report_${env}.json -t installation -r
  unset SPACK_ENV
  mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_install.out
  mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_install.log
done

for env in $cray_env_list; do
  echo "Running ReFrame tests for modules in env $env"
  export SPACK_ENV=${env}
  reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_install_report_${env}.json -t installation -r
  unset SPACK_ENV
  mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_install.out
  mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_install.log
done

# Reset valid setonix hostnames to original entries (i.e. remove the node this job runs on) for future runs
sed -i "s/\(hostnames.*setonix-01.*\)\(,.*\]\)/\1]/" ${RFM_SETTINGS_FILE}