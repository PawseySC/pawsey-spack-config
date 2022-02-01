#!/bin/bash

# TODO: most of this to be turned into Spack recipe

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# load needed python toolkit
module load $python_module/$python_version
module load setuptools/$setuptools_version
module load pip/$pip_version

# create and enter install directory
mkdir shpc
cd shpc

# pip install package
pip install --prefix=$(pwd) singularity-hpc==$shpc_version

# get registry from github repo
git clone https://github.com/singularityhub/singularity-hpc
cd singularity-hpc
git checkout $shpc_version
cd ..
mv singularity-hpc/registry .
rm -fr singularity-hpc

# fix long shebang
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/shpc
# the one below only because all dep packages are in same path
sed -i "s;/.*/python.*$;/bin/sh\n'''exec' & \"\$0\" \"\$@\"\n' ''';g" bin/spython

# need to configure shpc for use, to change configs
export PATH=$(pwd)/bin:$PATH
export PYTHONPATH=$(pwd)/lib/python${python_version_major}.${python_version_minor}/site-packages:$PYTHONPATH

#### ALL SHPC CONFIG COMMANDS HERE



cd ..
