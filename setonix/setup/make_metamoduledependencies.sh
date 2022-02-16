#!/bin/bash

## Setup a meta-module for a package that loads all the dependencies
if [ "$#" -ne 3 ];  then
    echo "Usage is <package> <path_to_env> <path_to_modules>"
    echo "Script will cd to the environment, activate it, check the concretisation, update the module and copy it to the module path"
    exit
fi

package=$1
envpath=$2
modpath=$3

if [ ! -d $envpath ]; then
    echo "Environment path ${envpath} does not exist. Exiting"
    exit
fi 

if [ ! -d $modpath ]; then
    echo "Module path ${modpath} does not exist. Exiting"
    exit
fi 

modfilebase=${package}-dependencies.base.lua
modfile=${modpath}/${package}-dependencies.lua
echo "Setting up $package"
isspack=$(which spack)
echo $isspack
if [ -z ${isspack} ]; then
    echo "Spack must be loaded."
    exit
fi
echo "Using ${isspack}"
spack debug report

echo "Entering ${envpath} ... "
cd ${envpath}
spack env activate . 
spack concretize -f > ${package}.concretize 
spack env deactivate 
numlines=$(wc -l ${package}.concretize | awk '{print $1}')

# header has three lines, remove them 
numlines=$(($numlines-3))
tail -n ${numlines} ${package}.concretize > tmp.txt
mv tmp.txt ${package}.concretize

# now for the first line, get the hash and the spec of the main package 
package_hash=$(head -1 ${package}.concretise | awk '{print $2}')
package_spec=$(head -1 ${package}.concretise | awk '{$1="";$2="";print}')

cp ${modfilebase} ${modfile}

# now get all the other packages 
for ((i=1;i<${numlines};i++))
do
    hash=$(head -1 ${package}.concretise | awk '{print $2}')
    basemodname=$(spack module lmod find /${hash})
    if [ -z ${basemodname} ]; then
        echo "load(\"${basemodname}\")" >> ${modfile}
    fi
    basemodname=""
done




