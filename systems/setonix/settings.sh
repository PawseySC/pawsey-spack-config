#!/bin/bash
if [ -z ${__PSC_VARIABLES__+x} ]; then # include guard
__PSC_VARIABLES__=1

# EDIT at each rebuild of the software stack
DATE_TAG="2023.01"

if [ -z ${INSTALL_PREFIX+x} ]; then
    echo "The 'INSTALL_PREFIX' variable is not set. Please specify the installation
    path for the software stack being built."
    exit 1
elif [ "${INSTALL_PREFIX%$DATE_TAG}" = "${INSTALL_PREFIX}" ]; then
    echo "The path in 'INSTALL_PREFIX' must end with ${DATE_TAG} but its value is ${INSTALL_PREFIX}"
    exit 1
fi

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

if [ "$USER" = "spack" ]; then
    INSTALL_GROUP="spack"
fi

if [ -z ${INSTALL_GROUP+x} ]; then
    echo "The 'INSTALL_GROUP' variable must be set to linux group that will own the installed files."
    exit 1
fi

pawseyenv_version="${DATE_TAG}"

# compiler versions (needed for module trees with compiler dependency)
gcc_version="12.1.0"
cce_version="14.0.3"
aocc_version="3.2.0"
# architecture of login/compute nodes (needed by Singularity symlink module)
cpu_arch="zen3"
# all archs to support
archs="zen3 zen2"

# tool versions
spack_version="0.19.0" # the prefix "v" is added in setup_spack.sh
singularity_version="3.8.6" # has to match the version in the Spack env yaml
shpc_version="0.0.57"

# python (and py tools) versions
python_name="python"
python_version="3.9.15" # has to match the version in the Spack env yaml
setuptools_version="57.4.0" # has to match the version in the Spack env yaml
pip_version="22.2.2" # has to match the version in the Spack env yaml
# r major minor version
r_version_majorminor="4.1"

# list of module categories
module_cat_list="
astro-applications
bio-applications
applications
libraries
programming-languages
utilities
visualisation
python-packages
benchmarking
developer-tools
dependencies
"

# list of spack build environments - missing env_vis
env_list="
env_utils
env_num_libs
env_python
env_io_libs
env_langs
env_apps
env_devel
env_bench
env_s3_clients
env_astro
env_bio
env_roms
env_wrf
"

### TYPICALLY NO EDIT NEEDED PAST THIS POIINT

# python version info (no editing needed)
python_version_major="$( echo $python_version | cut -d '.' -f 1 )"
python_version_minor="$( echo $python_version | cut -d '.' -f 2 )"
python_version_bugfix="$( echo $python_version | cut -d '.' -f 3 )"

# shpc module directories for all users (system-wide and user-specific)
shpc_allusers_modules_dir_long="modules-long"
shpc_allusers_modules_dir_short="views/modules"
# shpc module suffix for SPACK USER (system-wide)
shpc_spackuser_container_tag="-container"
# name of SHPC module: decide this once and for all
shpc_name="shpc"

# name of Singularity module (Spack has singularity and singularityce)
singularity_name="singularity"

# NOTE: the following are ALL RELATIVE to root_dir above
# root location for Pawsey custom builds
custom_root_dir="custom"
# root location for Pawsey utilities (spack, shpc, scripts)
utilities_root_dir="pawsey"
# root location for containers
containers_root_dir="containers"
# location for Pawsey custom build modules
custom_modules_dir="${custom_root_dir}/modules"
# location for Pawsey custom build software
custom_software_dir="${custom_root_dir}/software"
# location for Pawsey utility modules
utilities_modules_dir="${utilities_root_dir}/modules"
# location for Pawsey utility software
utilities_software_dir="${utilities_root_dir}/software"
# location for SHPC container modules
shpc_containers_modules_dir="${containers_root_dir}/${shpc_allusers_modules_dir_short}"
# location for SHPC container modules (long version, as installed)
shpc_containers_modules_dir_long="${containers_root_dir}/${shpc_allusers_modules_dir_long}"
# location for SHPC containers
shpc_containers_dir="${containers_root_dir}/sif"

# suffix for Pawsey custom build modules
custom_modules_suffix="custom"
# suffix for Project modules
project_modules_suffix=""   # "project-apps" # let us keep it standard vs spack
# suffix for User modules
user_modules_suffix=""   # "user-apps" # let us keep it standard vs spack

# location of SHPC utility installation
shpc_install_dir="${utilities_software_dir}/${shpc_name}"
# location of SHPC utility modulefile
shpc_module_dir="${utilities_modules_dir}/${shpc_name}"

# location of Singularity modulefile (arch/compiler free symlink)
singularity_symlink_module_dir="${utilities_modules_dir}/${singularity_name}"

# location for Spack modulefile
spack_module_dir="${utilities_modules_dir}/spack"

# location for pawsey_temp module (pawsey staff use)
pawsey_temp="pawsey_temp"

fi # end include guard