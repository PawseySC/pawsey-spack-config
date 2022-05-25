#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(dirname $0 2>/dev/null || pwd)"
. ${script_dir}/variables.sh

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
# spec gcc
spack spec python@3.9.7 +optimizations %gcc@11.2.0 target=zen3 1> ${logdir}/spack.python.concretize.log 2> ${logdir}/spack.python.concretize.err

# install gcc
sg $PAWSEY_PROJECT -c 'spack install python@3.9.7 +optimizations %gcc@11.2.0 target=zen3' 1> ${logdir}/spack.python.install.log 2> ${logdir}/spack.python.install.err
# install cce
sg $PAWSEY_PROJECT -c 'spack install python@3.9.7 +optimizations %cce@13.0.2 target=zen3' 1>> ${logdir}/spack.python.install.log 2>> ${logdir}/spack.python.install.err
# install aocc
sg $PAWSEY_PROJECT -c 'spack install python@3.9.7 +optimizations %aocc@3.2.0 target=zen3' 1>> ${logdir}/spack.python.install.log 2>> ${logdir}/spack.python.install.err
