#!/bin/bash 
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
source ${script_dir}/.spack_check.sh

# basic check for environments
isspackyaml=$(ls spack.yaml 1> /tmp/found-yaml 2>/dev/null; more /tmp/found-yaml)
if [ -z ${isspackyaml} ]; then 
    echo "${env} does not contain a spack.yaml, please check this is valid environment"
    exit
fi
