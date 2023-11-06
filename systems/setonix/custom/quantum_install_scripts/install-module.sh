#!/bin/bash 

INSTALL_DIR=$1
NAME=$2
VERSION=$3
BRIEF=$4
DESCRIP=$5
# might need to update the path 
MOD_PATH=/software/setonix/2023.08/modules/zen3/gcc/12.2.0/custom/

echo "${MOD_PATH}/${NAME}/"
mkdir -p ${MOD_PATH}/${NAME}/
modname=${MOD_PATH}/${NAME}/${VERSION}.lua
cp sample.lua ${modname}

fields=(INSTALL_PATH NAME VERSION BRIEF DESCRIP)
values=("${INSTALL_DIR}" "${NAME}" "${VERSION}" "${BRIEF}" "${DESCRIP}")
for ((i=0;i<5;i++))
do
    echo "${fields[${i}]} ${values[${i}]}"
    sed -i "s:${fields[${i}]}:${values[${i}]}:g" ${modname}
done