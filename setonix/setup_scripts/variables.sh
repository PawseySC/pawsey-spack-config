#!/bin/bash

# EDIT at each rebuild of the software stack
date_tag="2022.05"

# compiler versions (needed for module trees with compiler dependency)
gcc_version="11.2.0"
cce_version="13.0.2"
aocc_version="3.2.0"
# architecture of login/compute nodes (needed by Singularity symlink module)
cpu_arch="zen3"

# tool versions
spack_version="0.17.0" # the prefix "v" is added in setup_spack.sh
singularity_version="3.8.6" # has to match the version in the Spack env yaml
shpc_version="0.0.53"

# python (and py tools) versions
python_name="python"
python_version="3.9.7" # has to match the version in the Spack env yaml
setuptools_version="57.4.0" # has to match the version in the Spack env yaml
pip_version="21.1.2" # has to match the version in the Spack env yaml
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

# list of spack build environments
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

# if you change this, you need to propagate also in other places (mostly Spack config yamls)
top_root_dir="/software/setonix"
root_dir="${top_root_dir}/${date_tag}"

# python version info (no editing needed)
python_version_major="$( echo $python_version | cut -d '.' -f 1 )"
python_version_minor="$( echo $python_version | cut -d '.' -f 2 )"
python_version_bugfix="$( echo $python_version | cut -d '.' -f 3 )"

# shpc module directory for SPACK USER (system wide installation)
shpc_spackuser_modules_dir_long="modules-long"
shpc_spackuser_modules_dir_short="modules"
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
shpc_containers_modules_dir="${containers_root_dir}/${shpc_spackuser_modules_dir_short}"
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
