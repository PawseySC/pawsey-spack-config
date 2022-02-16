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

modfilebase=base-meta-module-dependencies.lua
modfile=${modpath}/${package}-dependencies.lua
cp ${modfilebase} ${modfile}

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
# get concretization 
spack env activate . 
spack concretize -f > ${package}.concretize 
spack env deactivate 

# header has three lines, remove them 
numlines=$(wc -l ${package}.concretize | awk '{print $1}')
numlines=$(($numlines-3))
tail -n ${numlines} ${package}.concretize > tmp.txt
mv tmp.txt ${package}.concretize

# now for the first line, get the hash and the spec of the main package 
package_hash=$(head -1 ${package}.concretize | awk '{print $2}')
package_spec=$(head -1 ${package}.concretize | awk '{$1="";$2="";print}')

sed -i 's/PACKAGE_VERSION/'"${package_spec}"'/g' ${modfile}
sed -i 's/PACKAGE_NAME/'"${package}"'/g' ${modfile}

# now get all the other packages 
for ((i=2;i<${numlines};i++))
do
    hash=$(head -n ${i} ${package}.concretize | tail -n 1 | awk '{print $2}')
    dep=$(head -n ${i} ${package}.concretize | tail -n 1 | awk '{print $3}')
    basemodname=$(spack module lmod find /${hash})
    if [ ! -z ${basemodname} ]; then
        echo "load(\"${basemodname}\")" >> ${modfile}
    else 
        echo "Dependency module not found! "
        echo "Missing ${dep} with hash ${hash}"
    fi
    basemodname=""
done

rm ${package}.concretize

echo "Done updating module. Now have "
more ${modfile}
