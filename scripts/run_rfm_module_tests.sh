#!/bin/bash

# THIS IS THE SCRIPT INTENDED TO BE RUN DURING THE SOFTWARE STACK INSTALLATION PIPELINE
# This script runs Reframe module tests across all environments EXCEPT apps
# given the number of manual installations that are required for that environment
# This script also excludes tests which are known to fail all the time (due to issues
# with currently unknown fixes)
# To run all module tests (including ones which always fail) run the script "run_all_rfm_module_tests.sh"

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

module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}

# Add node this job is running on to host list of ReFrame, allowing it to run from this node
sed -i "s/\(hostnames.*setonix-01.*\).*\(\]\)/\1,'${SLURM_JOB_NODELIST}'\2/" ${RFM_SETTINGS_FILE}

# These need to be exported to be visible within Reframe
export PAWSEY_SPACK_CONFIG_REPO=${PAWSEY_SPACK_CONFIG_REPO}
export cce_version=${cce_version}
export gcc_version=${gcc_version}
export python_version=${python_version}

# Reframe testing for modules
module load reframe/${reframe_version}
for env in $env_list; do
  if [ "$env" != "apps" -a "$env" != "wrf" -a "$env" != "roms" ]; then
    echo "Running ReFrame tests for modules in env $env"
    export SPACK_ENV=${env}
    reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_install_report_${env}.json -t installation -r
    unset SPACK_ENV
    mv reframe.out ${RFM_STORAGE_DIR}/reframe_${env}_install.out
    mv reframe.log ${RFM_STORAGE_DIR}/reframe_${env}_install.log
  fi
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