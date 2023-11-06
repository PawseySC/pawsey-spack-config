#!/bin/bash 

INSTALL_DIR=$1
NAME=$2
VERSION=$3
BRIEF=$4
DESCRIP=$5

echo "${MODULE_DIR}/${NAME}/"
mkdir -p ${MODULE_DIR}/${NAME}/
modname=${MODULE_DIR}/${NAME}/${VERSION}.lua
cp sample.lua ${modname}

fields=(INSTALL_PATH NAME VERSION BRIEF DESCRIP)
values=("${INSTALL_DIR}" "${NAME}" "${VERSION}" "${BRIEF}" "${DESCRIP}")
for ((i=0;i<5;i++))
do
    echo "${fields[${i}]} ${values[${i}]}"
    sed -i "s:${fields[${i}]}:${values[${i}]}:g" ${modname}
done