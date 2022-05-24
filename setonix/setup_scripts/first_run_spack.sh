#!/bin/bash

# first run with Spack after setup

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# use PrgEnv-gnu
module swap PrgEnv-cray/8.3.2 PrgEnv-gnu

# for first run, use cray-python, because there is no Spack python yet
module load cray-python

. ${root_dir}/spack/share/spack/setup-env.sh 

# make sure Clingo is bootstrapped
spack spec nano

# first thing we need is Python
# spec
spack spec python@3.9.7 +optimizations %gcc@11.2.0 target=zen3
# define log directory
log_dir="${root_dir}/logs/$( date -Iminutes | sed 's/+.*//' | tr ':' '.' )"
mkdir -p ${log_dir}
cd ${log_dir}
# install
sg $PAWSEY_PROJECT -c 'spack install python@3.9.7 +optimizations %gcc@11.2.0 target=zen3' |& tee log_python
