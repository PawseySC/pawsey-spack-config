#!/bin/bash 

function install_module()
{
    local INSTALL_DIR=$1
    local NAME=$2
    local VERSION=$3
    local BRIEF=$4
    local DESCRIP=$5

    echo "${MODULE_DIR}/${NAME}/"
    mkdir -p ${MODULE_DIR}/${NAME}/
    local modname=${MODULE_DIR}/${NAME}/${VERSION}.lua
    cp ${script_dir}/sample.lua ${modname}

    # update lua module
    local fields=(INSTALL_PATH NAME VERSION BRIEF DESCRIP)
    local values=("${INSTALL_DIR}" "${NAME}" "${VERSION}" "${BRIEF}" "${DESCRIP}")
    for ((i=0;i<5;i++))
    do
        echo "${fields[${i}]} ${values[${i}]}"
        sed -i "s:${fields[${i}]}:${values[${i}]}:g" ${modname}
    done

    # add the dependencies
    local dstring=""
    for d in ${dependencies[@]}
    do
        dstring+="load(${d})\n"
    done

    sed -i "s:-- dependencies:${dstring}:g" ${modname}
}

function set_dependencies()
{
    for d in ${dependencies[@]}
    do
        module load ${d}
    done
}