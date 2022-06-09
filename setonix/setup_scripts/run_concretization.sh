#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# list of environments included in variables.sh (sourced above)

envdir="${script_dir}/../environments"

timestamp="$(date +"%Y-%m-%d_%Hh%M")"
top_logdir="${SPACK_LOGS_BASEDIR:-"${script_dir}/logs"}"
logdir="${top_logdir}/concretization.${timestamp}"
mkdir -p ${logdir}
for env in ${env_list} ; do
  cd ${envdir}/${env}
  spack env activate . 
  spack concretize -f 1> ${logdir}/spack.concretize.${env}.log 2> ${logdir}/spack.concretize.${env}.err
  spack env deactivate
  cd ${script_dir}
done 
