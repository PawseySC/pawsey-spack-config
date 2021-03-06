#!/bin/bash

## Setup a meta-module for a package that loads all the dependencies
if [ "$#" -ne 3 ];  then
    echo "Usage is <package> <path_to_env> <path_to_modules>"
    echo "Script will cd to the environment, activate it, check the concretisation, update the module and copy it to the module path"
    exit
fi

package=$1
envpath=$(readlink -f $2)
modpath=$(readlink -f $3)

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

if [ ! -d $envpath ]; then
    echo "Environment path ${envpath} does not exist. Exiting"
    exit
fi 

if [ ! -d $modpath ]; then
    echo "Module path ${modpath} does not exist. Exiting"
    exit
fi 

modfilebase=${script_dir}/setup_templates/base-meta-module-dependencies.lua

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
output_concretize="${envpath}/${package}.concretize"
# get concretization 
spack env activate ${envpath} 
spack concretize -f > ${output_concretize} 
spack env deactivate 

# header has three lines, remove them 
numlines=$(wc -l ${output_concretize} | awk '{print $1}')
numlines=$(($numlines-3))
tail -n ${numlines} ${output_concretize} > ${envpath}/tmp.txt
mv ${envpath}/tmp.txt ${output_concretize}

# now for the first line, get the hash and the spec of the main package 
package_hash=$(head -1 ${output_concretize} | awk '{print $2}')
package_spec=$(head -1 ${output_concretize} | awk '{$1="";$2="";print}')
package_version=$(head -1 ${output_concretize} | sed 's/@/ /'g | sed 's/%/ /g' | awk '{$1="";$2="";print $4}')
modfile=${modpath}/${package}-dependency-set.lua
cp ${modfilebase} ${modfile}

sed -i 's/PACKAGE_SPEC/'"${package_spec}"'/g' ${modfile}
sed -i 's/PACKAGE_VERSION/'"${package_version}"'/g' ${modfile}
sed -i 's/PACKAGE_NAME/'"${package}"'/g' ${modfile}

# now get all the other packages 
for ((i=2;i<${numlines};i++))
do
    hash=$(head -n ${i} ${output_concretize} | tail -n 1 | awk '{print $2}')
    dep=$(head -n ${i} ${output_concretize} | tail -n 1 | awk '{print $3}')
    basemodname=$(spack module lmod find /${hash})
    if [ ! -z ${basemodname} ]; then
        echo "load(\"${basemodname}\")" >> ${modfile}
    else 
        echo "Dependency module not found! "
        echo "Missing ${dep} with hash ${hash}"
    fi
    basemodname=""
done

rm ${output_concretize}

# now strip key strings from the modules that are loaded. 
# list of module categories included in variables.sh (sourced above)

for mod_cat in ${module_cat_list}
do
    s="${mod_cat}/"
    sed -i 's:load("'"${s}"':load(":g' ${modfile}
done

echo "Done updating module. Now have "
more ${modfile}
