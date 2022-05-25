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
    local envdir="${1:-"."}"
    # use just the innest dir in the path as env name
    local env="${envdir##*/}"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.concretize.env.${timestamp}.${env}"
    spack env activate ${envdir}
    spack concretize -f 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    # also check if concretization has duplicates. still needs fleshing out
    local duplicate_list="$(spack_check_duplicate ${logdir}/${logfile}.log)"
    spack env deactivate
}


function spack_env_install()
{
    # default to environment being the current dir
    local envdir="${1:-"."}"
    # use just the innest dir in the path as env name
    local env="${envdir##*/}"
    local nprocs="${2:-"16"}"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.install.env.${timestamp}.${env}"
    spack env activate ${envdir}
    spack concretize -f 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    sg $PAWSEY_PROJECT -c "spack install -j${nprocs} 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
    spack env deactivate
}


function spack_env_with_git_install()
{
    spack clean -dspm
    spack_env_install $1 $2
}


function spack_spec()
{
    local args="$@"
    local tool="${args%%@*}"
    local tool="${tool##* }"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.spec.${timestamp}.${tool}"
    spack spec -I "$args" 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
}


function spack_install()
{
    local args="$@"
    local tool="${args%%@*}"
    local tool="${tool##* }"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.install.${timestamp}.${tool}"
#    spack spec -I "$args" 1> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    sg $PAWSEY_PROJECT -c "spack install "$args" 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
}


function spack_uninstall()
{
    local args="$@"
    local tool="${args%%@*}"
    local tool="${tool##* }"
    local timestamp="$(get_timestamp)"
    local logdir="$(pwd)"
    local logfile="spack.uninstall.${timestamp}.${tool}"
    sg $PAWSEY_PROJECT -c "spack uninstall "$args" 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
}


export -f get_timestamp() 
export -f spack_check_duplicate()
export -f spack_env_concretize() 
export -f spack_env_install()
export -f spack_env_with_git_install()
export -f spack_spec()
export -f spack_install()
export -f spack_uninstall()
