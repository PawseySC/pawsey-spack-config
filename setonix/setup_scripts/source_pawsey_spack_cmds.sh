#!/bin/bash 

# This script, when sourced provides several useful 
# bash functions that automatically: 
# - concretize environments, saving the output to a log
# - install an environment, saving output ot a log
# etc.


function get_timestamp() 
{
    local format="${1:-"%Y-%m-%d_%Hh%M"}"
    local timestamp="$(date +${format})"
    echo "$timestamp"
}


function spack_check_duplicate()
{
    local file="$1"
}

function spack_examine_concretize_err() 
{
    local log=$1
    local numerr=$(grep -c -a "unsatisfiable" ${log})
    echo "Concretize Error log has ${numerr} errors"
    grep "unsatisfiable" ${log}
}

function spack_examine_install_err() 
{
    local log=$1
    local numerr=$(grep -c -a "==> Error:" ${log})
    if [ "$numerr" = "0" ]
    then 
        return
    fi
    errtypes=("FetchError:" "ProcessError:")
    for et in ${errtypes[@]}
    do
        numerr=$(grep -c -a ${et} ${log})
        if [ "$numerr" > "0" ]
        then
            #echo "Error log contains ${numerr} ${et}"
            if [ ${et} = "FetchError:" ]
            then
                local num=$(($(grep -c -a "${et} Manual download" ${log})/2))
                grep -a "${et} Manual download" ${log} | tail -n ${num} > /tmp/messages.txt
                for ((i=1;i<=${num};i++))
                do
                    m=$(head -n ${i} /tmp/messages.txt | tail -1)
                    local spackbuild=$(echo ${m} | awk '{print $3}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Manual download required for ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.txt
                local num=$(($(grep -c -a "${et} Will not fetch" ${log})/2))
                grep -a "${et} Will not fetch" ${log} | tail -n ${num} > /tmp/messages.txt
                for ((i=1;i<=${num};i++))
                do
                    m=$(head -n ${i} /tmp/messages.txt | tail -1)
                    local spackbuild=$(echo ${m} | awk '{print $3}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Unable to fetch ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.txt
            fi
            if [ ${et} = "ProcessError:" ]
            then
                local num=$(grep -c -a "spack-build-out.txt" ${log})
                grep -a "spack-build-out.txt" ${log} > /tmp/messages.txt
                for ((i=1;i<=${num};i++))
                do
                    m=$(head -n ${i} /tmp/messages.txt | tail -1)
                    local spackbuild=$(echo ${m} | sed 's:build_stage/: :g' | sed 's:/spack-build: :g' | sed 's:spack-stage-::'g| awk '{print $2}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Error building ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.txt
            fi
        fi
    done
}

function spack_env_concretize() 
{
    # environment dir is always the current dir
    # use just the innest dir in the path as env name
    local env="$(pwd)"
    local env="${env##*/}"
    local timestamp="$(get_timestamp)"
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # Marco: I have ideas on how to improve this
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs"}
    fi
    mkdir -p $logdir
    local logfile="spack.concretize.env.${timestamp}.${env}"
    # environment dir is always the current dir
    spack env activate .
    echo "ENV_DIR: $(pwd)" > ${logdir}/${logfile}.log
    spack concretize -f 1>> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    spack_examine_concretize_err ${logdir}/${logfile}.err
    # also check if concretization has duplicates. still needs fleshing out
    local duplicate_list="$(spack_check_duplicate ${logdir}/${logfile}.log)"
    spack env deactivate
}


function spack_env_install()
{
    local args="$@"
    # environment dir is always the current dir
    # use just the innest dir in the path as env name
    local env="$(pwd)"
    local env="${env##*/}"
    local timestamp="$(get_timestamp)"
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # Marco: I have ideas on how to improve this
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs"}
    fi
    mkdir -p $logdir
    local logfile="spack.install.env.${timestamp}.${env}"
    # environment dir is always the current dir
    spack env activate .
    echo "ENV_DIR: $(pwd)" > ${logdir}/${logfile}.log
    spack concretize -f 1>> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    spack_examine_concretize_err ${logdir}/${logfile}.err
    sg $PAWSEY_PROJECT -c "spack install ${args} 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
    spack_examine_install_err ${logdir}/${logfile}.err
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
    local timestamp="$(date +"%Y-%m-%d")"
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # Marco: I have ideas on how to improve this
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs"}
    fi
    mkdir -p $logdir
    local logfile="spack.spec.${timestamp}"
    spack spec -I "$args" 1> /tmp/${logfile}.log 2> /tmp/${logfile}.err
    spack_examine_concretize_err /tmp/${logfile}.err
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.err >> ${logdir}/${logfile}.err
}


function spack_install()
{
    local args="$@"
    local tool="${args%%@*}"
    local tool="${tool##* }"
    local timestamp="$(date +"%Y-%m-%d")"
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # Marco: I have ideas on how to improve this
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs"}
    fi
    mkdir -p $logdir
    local logfile="spack.install.${timestamp}"
    sg $PAWSEY_PROJECT -c "spack install "$args" 1> /tmp/${logfile}.log 2> /tmp/${logfile}.err"
    spack_examine_install_err /tmp/${logfile}.err
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.err >> ${logdir}/${logfile}.err
}


function spack_uninstall()
{
    local args="$@"
    local tool="${args%%@*}"
    local tool="${tool##* }"
    local timestamp="$(date +"%Y-%m-%d")"
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # Marco: I have ideas on how to improve this
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs"}
    fi
    mkdir -p $logdir
    local logfile="spack.uninstall.${timestamp}.${tool}"
    sg $PAWSEY_PROJECT -c "spack uninstall "$args" 1> /tmp/${logfile}.log 2> /tmp/${logfile}.err"
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.err >> ${logdir}/${logfile}.err
}


export -f get_timestamp 
export -f spack_examine_concretize_err
export -f spack_examine_install_err
export -f spack_check_duplicate
export -f spack_env_concretize 
export -f spack_env_install
export -f spack_env_with_git_install
export -f spack_spec
export -f spack_install
export -f spack_uninstall