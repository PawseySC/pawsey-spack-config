#!/bin/bash
#SBATCH --job-name="rfm_sw_stack"
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=1-00:00:00
#SBATCH --account=pawsey0001

#################
# ReFrame setup #
#################
# NOTE: This will not be final. Probably need to do something similar to install_python.sh to install ReFrame separately
module load reframe/3.10.1
# Set ReFrame environment variables
export RFM_REPO_PATH=/scratch/pawsey0001/cmeyer/pawsey_test_suite/reframe
export RFM_SETTINGS_FILE=${RFM_REPO_PATH}/setup_files/settings.py
export RFM_STORAGE_DIR=/scratch/pawsey0001/cmeyer/rfm_sw_stack_setonix_2024.02
# NOTE: Will switch to cloned repo when my tests added to git repo
export RFM_TEST_FILE=/software/projects/pawsey0001/cmeyer/pawsey_test_suite/reframe/pawsey_checks/spack/spack_full_mod_checks.py
# Add node this job is running on to host list of ReFrame, allowing it to run from this node
sed -i "s/\(hostnames.*setonix-01.*\).*\(\]\)/\1,'${SLURM_JOB_NODELIST}'\2/" ${RFM_SETTINGS_FILE}

# Set environment variables for software stack installation script
export SYSTEM=setonix
export INSTALL_GROUP=pawsey0001
export INSTALL_PREFIX=/scratch/pawsey0001/cmeyer/setonix/2024.02
# Run installation script
./install_software_stack.sh

# Reset valid setonix hostnames to original entries (i.e. remove the node this job runs on) for future runs
sed -i "s/\(hostnames.*setonix-01.*\)\(,.*\]\)/\1]/" ${RFM_SETTINGS_FILE}
