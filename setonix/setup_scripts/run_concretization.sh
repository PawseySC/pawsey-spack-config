#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# spack module
is_loaded_spack="$( module is-loaded spack/${spack_version} ; echo "$?" )"
if [ "${is_loaded_spack}" != "0" ] ; then
  module load spack/${spack_version}
fi


# list of environments included in variables.sh (sourced above)

envdir="${script_dir}/../environments"

timestamp="$(date +"%Y-%m-%d_%Hh%M")"
top_logdir="${SPACK_LOGS_BASEDIR:-"${script_dir}/logs"}"
logdir="${top_logdir}/concretization.${timestamp}"
mkdir -p ${logdir}
for env in ${env_list} ; do
  spack env activate ${envdir}/${env} 
  spack concretize -f 1> ${logdir}/spack.concretize.${env}.log 2> ${logdir}/spack.concretize.${env}.err
  spack env deactivate
done 
