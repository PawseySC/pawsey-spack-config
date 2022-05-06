#!/bin/bash

# EDIT at each rebuild of the software stack
date_tag="2022.01"
root_dir="/software/setonix/${date_tag}"

spack_version="v0.17.0"
singularity_version="3.8.5"
shpc_version="0.0.37"  # will change before Setonix deployment

python_module="python"
python_version="3.9.7"
setuptools_version="57.4.0"
pip_version="21.1.2"

python_version_major="$( echo $python_version | cut -d '.' -f 1 )"
python_version_minor="$( echo $python_version | cut -d '.' -f 2 )"
python_version_bugfix="$( echo $python_version | cut -d '.' -f 3 )"
