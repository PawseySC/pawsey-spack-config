#!/bin/bash -e

# this script goes through 5 steps
# 1. refresh spack modules
# 2. create all missing module directories
# 3. update singularity modules
# 4. refresh wrf/roms dependency modules
# 5. create hpc-python view and module
# 6. apply licensing permissions
# 7. customise shpc symlink modules

# source setup variables
# if copy/pasting these commands, need to run from this directory
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

#step 1 - refreshing spack modules
#this step is now run in install_environments.sh
##echo "Deleting and re-creating Spack modules.."
#spack module lmod refresh -y --delete-tree


# step 2. create all missing module directories
echo "Creating all missing module directories.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_system_moduletree.sh"


# step 3. update singularity modules
#echo "Updating Singularity modules.."
#this is now performed in install_software_stack.sh script
#"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_custom_singularity_modules.sh"


# step 4. refresh wrf/roms dependency modules
echo "Refreshing wrf/roms dependency modules.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_wrf_roms_dependency_modules.sh"


# step # 5. create hpc-python view and module
echo "Creating hpc-python view and module.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/create_hpc_python_collection_view_module.sh"


# step 6. apply licensing permissions
echo "Apply licensing permissions.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/set_licensing_permissions.sh"

# step 7. customise shpc container modules
echo "Customising shpc container modules.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/patch_shpc_pawsey_modules.sh"

# step 8, run previous manual steps outlined in 2024.05 deployment CRs
echo "Executing CRs"
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/cr_operations.sh

# step 8, run reframe tests for module generation and functionality
echo "Running spack reframe tests.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/run_rfm_module_tests.sh"
