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


function get_daystamp()
{
    local format="${1:-"%Y-%m-%d"}"
    local daystamp="$(date +${format})"
    echo "$daystamp"
}


function get_logdir()
{
    if [ "$USER" == "spack" ] ; then
        local date_tag="2022.05" # DATE_TAG
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/setonix/${date_tag}/software/${USER}/logs"}
    else
        local logdir=${SPACK_LOGS_BASEDIR:-"/software/projects/${PAWSEY_PROJECT}/${USER}/setonix/software/$USER/logs"}
    fi
    echo "$logdir"
}


function get_install_group()
{
    if [ "$USER" == "spack" ] ; then
      echo "spack"
    else
      echo "$PAWSEY_PROJECT"
    fi
}


function spack_check_duplicate()
{
    #TODO: work in progress
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
    local errtypes=("FetchError:" "ProcessError:")
    local et
    for et in ${errtypes[@]}
    do
        local numerr=$(grep -c -a ${et} ${log})
        if [ "$numerr" > "0" ]
        then
            #echo "Error log contains ${numerr} ${et}"
            if [ ${et} = "FetchError:" ]
            then
                local num=$(($(grep -c -a "${et} Manual download" ${log})/2))
                grep -a "${et} Manual download" ${log} | tail -n ${num} > /tmp/messages.${USER}.txt
                local i
                for ((i=1;i<=${num};i++))
                do
                    local m=$(head -n ${i} /tmp/messages.${USER}.txt | tail -1)
                    local spackbuild=$(echo ${m} | awk '{print $3}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Manual download required for ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.${USER}.txt
                local num=$(($(grep -c -a "${et} Will not fetch" ${log})/2))
                grep -a "${et} Will not fetch" ${log} | tail -n ${num} > /tmp/messages.${USER}.txt
                local i
                for ((i=1;i<=${num};i++))
                do
                    local m=$(head -n ${i} /tmp/messages.${USER}.txt | tail -1)
                    local spackbuild=$(echo ${m} | awk '{print $3}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Unable to fetch ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.${USER}.txt
            fi
            if [ ${et} = "ProcessError:" ]
            then
                local num=$(grep -c -a "spack-build-out.txt" ${log})
                grep -a "spack-build-out.txt" ${log} > /tmp/messages.${USER}.txt
                local i
                for ((i=1;i<=${num};i++))
                do
                    local m=$(head -n ${i} /tmp/messages.${USER}.txt | tail -1)
                    local spackbuild=$(echo ${m} | sed 's:build_stage/: :g' | sed 's:/spack-build: :g' | sed 's:spack-stage-::'g| awk '{print $2}' | sed 's:-: :g')
                    read -a arr <<< "${spackbuild}"
                    echo "Error building ${arr[0]}@${arr[1]} : ${arr[2]}"
                done
                rm /tmp/messages.${USER}.txt
            fi
        fi
    done
}


function spack_env_concretize() 
{
    # environment dir is always the current dir
    # use just the innest dir in the path as env name
    local env="$( readlink -f $(pwd) )"
    local env="${env##*/}"
    local timestamp="$(get_timestamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.concretize.env.${timestamp}.${env}"
    # environment dir is always the current dir
    spack env activate ${env}
    echo "ENV_DIR: ${env}" > ${logdir}/${logfile}.log
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
    local env="$( readlink -f $(pwd) )"
    local env="${env##*/}"
    local timestamp="$(get_timestamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.install.env.${timestamp}.${env}"
    # environment dir is always the current dir
    spack env activate ${env}
    echo "ENV_DIR: ${env}" > ${logdir}/${logfile}.log
    spack concretize -f 1>> ${logdir}/${logfile}.log 2> ${logdir}/${logfile}.err
    spack_examine_concretize_err ${logdir}/${logfile}.err
    sg $(get_install_group) -c "spack install ${args} 1>> ${logdir}/${logfile}.log 2>> ${logdir}/${logfile}.err"
    spack_examine_install_err ${logdir}/${logfile}.err
    spack env deactivate
}


function spack_env_with_git_install()
{
    spack clean -dspm
    spack_env_install "$@"
}


function spack_spec()
{
    local args="$@"
    local timestamp="$(get_daystamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.spec.${timestamp}"
    spack spec -Il ${args} 1> /tmp/${logfile}.${USER}.log 2> /tmp/${logfile}.${USER}.err
    spack_examine_concretize_err /tmp/${logfile}.${USER}.err
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    echo "TIME: $(date)" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.err >> ${logdir}/${logfile}.err

    rm /tmp/${logfile}.${USER}.log /tmp/${logfile}.${USER}.err
}


function spack_install()
{
    local args="$@"
    local timestamp="$(get_daystamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.install.${timestamp}"
    sg $(get_install_group) -c "spack install ${args} 1> /tmp/${logfile}.${USER}.log 2> /tmp/${logfile}.${USER}.err"
    spack_examine_install_err /tmp/${logfile}.${USER}.err
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    echo "TIME: $(date)" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.err >> ${logdir}/${logfile}.err

    rm /tmp/${logfile}.${USER}.log /tmp/${logfile}.${USER}.err
}


function spack_uninstall()
{
    local args="$@"
    local timestamp="$(get_daystamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.uninstall.${timestamp}"
    sg $(get_install_group) -c "spack uninstall -y ${args} 1> /tmp/${logfile}.${USER}.log 2> /tmp/${logfile}.${USER}.err"
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    echo "TIME: $(date)" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.err >> ${logdir}/${logfile}.err

    rm /tmp/${logfile}.${USER}.log /tmp/${logfile}.${USER}.err
}


function spack_module_refresh()
{
    args="$@"
    local timestamp="$(get_daystamp)"
    local logdir="$(get_logdir)"
    mkdir -p $logdir
    local logfile="spack.module.${timestamp}"
    spack module lmod refresh -y ${args} 1> /tmp/${logfile}.${USER}.log 2> /tmp/${logfile}.${USER}.err
    echo "ARGS: ${args}" >> ${logdir}/${logfile}.log
    echo "TIME: $(date)" >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.log >> ${logdir}/${logfile}.log
    cat /tmp/${logfile}.${USER}.err >> ${logdir}/${logfile}.err

    rm /tmp/${logfile}.${USER}.log /tmp/${logfile}.${USER}.err
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
export -f spack_module_refresh
