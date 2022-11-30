#!/bin/bash

# this script goes through 5 steps
# 1. refresh spack modules
# 2. create all missing module directories
# 3. update singularity modules
# 4. refresh wrf/roms dependency modules
# 5. create hpc-python view and module
# 6. apply licensing permissions
# 7. refresh shpc symlink modules

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

# spack module
is_loaded_spack="$( module is-loaded spack/${spack_version} ; echo "$?" )"
if [ "${is_loaded_spack}" != "0" ] ; then
  module load spack/${spack_version}
fi


# step 1. refresh spack modules
echo "Do you want to delete and re-create the Spack modules? (yes/no)"
read spack_answer
if [ ${spack_answer,,} == "yes" ] ; then
  echo "Deleting and re-creating Spack modules.."
  spack module lmod refresh -y --delete-tree
else
  echo "Skipping refresh of Spack modules."
fi


# step 2. create all missing module directories
echo "Creating all missing module directories.."
bash "${script_dir}/update_create_system_moduletree.sh"


# step 3. update singularity modules
echo "Updating Singularity modules.."
bash "${script_dir}/update_singularity_pawsey_modules.sh"


# step 4. refresh wrf/roms dependency modules
echo "Do you want to refresh the wrf/roms dependency modules? (yes/no)"
read dependency_answer
if [ ${dependency_answer,,} == "yes" ] ; then
  echo "Refreshing wrf/roms dependency modules.."
  bash "${script_dir}/post_make_wrf_roms_dependency_modules.sh"
else
  echo "Skipping refresh of wrf/roms dependency modules."
fi


# step # 5. create hpc-python view and module
echo "Do you want to create the hpc-python view and module? (yes/no)"
read hpc_python_answer
if [ ${hpc_python_answer,,} == "yes" ] ; then
  echo "Creating hpc-python view and module.."
  bash "${script_dir}/post_make_hpc_python_collection_view_module.sh"
else
  echo "Skipping creation of hpc-python view and module."
fi


# step 6. apply licensing permissions
echo "In addition to module directories, do you want to apply "
echo "licensing permissions to software directories, too? (yes/no)"
read license_answer
if [ ${license_answer,,} == "yes" ] ; then
  bash ${script_dir}/post_set_licensing_permissions.sh
else
  bash ${script_dir}/post_set_licensing_permissions.sh only-modules
fi


# step 7. customise shpc container modules
echo "Do you want to customise the shpc container modules? (yes/no)"
read shpc_answer
if [ ${shpc_answer,,} == "yes" ] ; then
  echo "Customising shpc container modules.."
  bash ${script_dir}/post_customise_shpc_pawsey_modules.sh
else
  echo "Skipping customisation of shpc container modules."
fi
