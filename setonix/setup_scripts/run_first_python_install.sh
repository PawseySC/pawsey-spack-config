#!/bin/bash

# source setup variables
curdir=$(pwd)
script_dir=${curdir}/$(dirname $0)

# use PrgEnv-gnu
module swap PrgEnv-cray/8.3.2 PrgEnv-gnu
# for first run, use cray-python, because there is no Spack python yet
module load cray-python
# initialise spack 
. ${root_dir}/spack/share/spack/setup-env.sh 

# make sure Clingo is bootstrapped
spack spec nano

# define log directory
timestamp=$(date +"%Y-%m-%d_%Hh%M")
logdir=${script_dir}/logs/python.${timestamp}/
mkdir -p ${logdir}

# first thing we need is Python
# spec
spack spec python@3.9.7 +optimizations %gcc@11.2.0 target=zen3 1> ${logdir}/spack.python.concretize.${env}.log 2> ${logdir}/spack.python.concretize.${env}.err

# install
sg $PAWSEY_PROJECT -c 'spack install python@3.9.7 +optimizations %gcc@11.2.0 target=zen3' 1> ${logdir}/spack.python.install.${env}.log 2> ${logdir}/spack.python.install.${env}.err
