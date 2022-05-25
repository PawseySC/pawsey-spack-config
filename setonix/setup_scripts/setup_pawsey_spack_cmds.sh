#!/bin/bash 

# This script, when sourced provides several useful 
# bash functions that automatically: 
# - concretize environments, saving the output to a log
# - install an environment, saving output ot a log
# etc.


function get_timestamp() 
{
    local timestamp="$(date +"%Y-%m-%d_%Hh%M")"
    local  __resultvar="$1"
    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$timestamp'"
    else
        echo "$timestamp"
    fi
}


function spack_check_duplicate()
{
    local file="$1"
}


function spack_env_concretize() 
{
    # default to environment being the current dir
    local env="${1:-"."}"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.concretize.${timestamp}.${env}"
    spack env activate ${env}
    spack concretize -f 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    # also check if concretization has duplicates. still needs fleshing out
    local duplicate_list="$(spack_check_duplicate ${logdir}/${logfile}.log)"
    spack env deactivate
}


function spack_env_install()
{
    # default to environment being the current dir
    local env="${1:-"."}"
    local nprocs="${2:-"16"}"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.install.${timestamp}.${env}"
    spack env activate ${env}
    spack concretize -f 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    sg $PAWSEY_PROJECT -c "spack install -j${nprocs} 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
    spack env deactivate
}


function spack_env_with_git_install()
{
    spack clean -dspm
    spack_env_install $1 $2
}


export -f get_timestamp() 
export -f spack_check_duplicate()
export -f spack_env_concretize() 
export -f spack_env_install()
export -f spack_env_with_git_install()
