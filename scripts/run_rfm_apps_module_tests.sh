#!/bin/bash

# Run Reframe module tests across the apps environment ONLY
# Since many apps packages require manual steps after automatic pipeline
# it is not beneficial to include those tests during installation as many
# will always fail. Therefore, this script is intended to be run after the
# apps packages have been installed fully.

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

# Run the Reframe module tests for the apps environment
module load reframe/${reframe_version}
echo "Running ReFrame tests for modules in env apps"
export SPACK_ENV=apps
reframe -C ${RFM_SETTINGS_FILE} -c ${RFM_TEST_FILE} --prefix=${RFM_STORAGE_DIR} --report-file=${RFM_STORAGE_DIR}/rfm_install_report_apps.json -t installation -r
unset SPACK_ENV
mv reframe.out ${RFM_STORAGE_DIR}/reframe_apps_install.out
mv reframe.log ${RFM_STORAGE_DIR}/reframe_apps_install.log

# Reset valid setonix hostnames to original entries (i.e. remove the node this job runs on) for future runs
sed -i "s/\(hostnames.*setonix-01.*\)\(,.*\]\)/\1]/" ${RFM_SETTINGS_FILE}
