#!/bin/bash

nprocs=128
if [ ! -z $1 ]; then 
  nprocs=$1
fi

# source setup variables
curdir=$(pwd)
script_dir=${curdir}/$(dirname $0)

#list of environments
envs=(env_utils \
env_python \ 
env_langs \ 
env_devel \
env_num_libs \
env_io_libs \
env_apps \
env_benchmarking \
env_s3_clients \
env_astro \
env_bio)

envs_depsonly=(env_roms \ 
env_wrf)

envdir=${script_dir}/../environments/

timestamp=$(date +"%Y-%m-%d_%Hh%M")
logdir=${script_dir}/logs/install.${timestamp}/
mkdir -p ${logdir}

for env in ${envs[@]}
do 
  cd ${envdir}/${env}
  spack env activate . 
  spack concretize -f 1> ${logdir}/spack.concretize.${env}.log 2> ${logdir}/spack.concretize.${env}.err
  spack install --no-checksum -j${nprocs} > ${logdir}/spack.install.${env}.log 2> ${logdir}/spack.install.${env}.err
  spack env deactivate
  cd ${script_dir}
done 

for env in ${envs_depsonly[@]}
do
  cd ${envdir}/${env}
  spack env activate .
  spack concretize -f 1> ${logdir}/spack.concretize.${env}.log 2> ${logdir}/spack.concretize.${env}.err
  spack install --no-checksum -j${nprocs} --only dependecies 1> ${logdir}/spack.install.${env}.log 2> ${logdir}/spack.install.${env}.err
  spack env deactivate
  cd ${script_dir}
done

