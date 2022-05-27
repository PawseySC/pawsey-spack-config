#!/bin/bash

script_dir="$(readlink -f $(dirname $0) 2>/dev/null || pwd)"

#list of environments
envs=( \
env_utils \
env_num_libs \
env_python \
env_io_libs \
env_langs \
env_apps \
env_devel \
env_benchmarking \
env_s3_clients \
env_astro \
env_bio \
env_roms \
env_wrf \
)

envdir="${script_dir}/../environments"

timestamp="$(date +"%Y-%m-%d_%Hh%M")"
logdir="${script_dir}/logs/concretization.${timestamp}"
mkdir -p ${logdir}
for env in ${envs[@]}
do 
  cd ${envdir}/${env}
  spack env activate . 
  spack concretize -f 1> ${logdir}/spack.concretize.${env}.log 2> ${logdir}/spack.concretize.${env}.err
  spack env deactivate
  cd ${script_dir}
done 
