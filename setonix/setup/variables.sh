#!/bin/bash

# EDIT at each rebuild of the software stack
date_tag="2022.01"
# if you change this, you need to propagate also in other places (mostly Spack config yamls)
root_dir="/software/setonix/${date_tag}"

# tool versions
spack_version="0.17.0" # the prefix "v" is added in setup_spack.sh
singularity_version="3.8.6" # has to match the version in the Spack env yaml
shpc_name="shpc" # decide this once and for all
shpc_version="0.0.51"

# python (and py tools) versions
python_name="python"
python_version="3.9.7" # has to match the version in the Spack env yaml
setuptools_version="57.4.0" # has to match the version in the Spack env yaml
pip_version="21.1.2" # has to match the version in the Spack env yaml

# compiler versions
gcc_version="10.3.0"
cce_version="12.0.1"
aocc_version="3.0.0"

# location for Pawsey modules (eg spack, shpc)
pawsey_modules_dir="pawsey-modules"

# shpc module directory for SPACK USER (system wide installation)
shpc_spackuser_modules_dir_long="modules-long"
shpc_spackuser_modules_dir_short="modules"
shpc_spackuser_openfoam_add_prefix="containerised-"

# python version info (no editing needed)
python_version_major="$( echo $python_version | cut -d '.' -f 1 )"
python_version_minor="$( echo $python_version | cut -d '.' -f 2 )"
python_version_bugfix="$( echo $python_version | cut -d '.' -f 3 )"
