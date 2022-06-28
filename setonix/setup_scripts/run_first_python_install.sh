#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# for first run, use cray-python, because there is no Spack python yet
module load cray-python
# initialise spack 
. ${root_dir}/spack/share/spack/setup-env.sh 

# make sure Clingo is bootstrapped
spack spec nano

# define log directory
timestamp=$(date +"%Y-%m-%d_%Hh%M")
top_logdir="${SPACK_LOGS_BASEDIR:-"${script_dir}/logs"}"
logdir="${top_logdir}/python.${timestamp}"
mkdir -p ${logdir}

# first thing we need is Python
# spec gcc
spack spec python@3.9.7 +optimizations %gcc@11.2.0 target=zen3 1> ${logdir}/spack.python.concretize.log 2> ${logdir}/spack.python.concretize.err

# install gcc
sg spack -c 'spack install python@3.9.7 +optimizations %gcc@11.2.0 target=zen3' 1> ${logdir}/spack.python.install.log 2> ${logdir}/spack.python.install.err
# install cce
sg spack -c 'spack install python@3.9.7 +optimizations %cce@13.0.2 target=zen3' 1>> ${logdir}/spack.python.install.log 2>> ${logdir}/spack.python.install.err
# install aocc
sg spack -c 'spack install python@3.9.7 +optimizations %aocc@3.2.0 target=zen3' 1>> ${logdir}/spack.python.install.log 2>> ${logdir}/spack.python.install.err
