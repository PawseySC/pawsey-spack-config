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

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# spack module
module use "${INSTALL_PREFIX}/staff_modulefiles"
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}


if [ ! -d "${envpath}" ]; then
    echo "Environment path ${envpath} does not exist. Exiting"
    exit
fi 

if [ ! -d "${modpath}" ]; then
    echo "Module path ${modpath} does not exist. Exiting"
    exit
fi 

modfilebase="${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/base_metamodule_dependencies.lua"

echo "Setting up ${package}"

echo "Entering ${envpath} ... "
output_concretize="${envpath}/${package}.concretize"
# get concretization 
spack env activate "${envpath}" 
spack concretize -f > "${output_concretize}" 
spack env deactivate 

# header has three lines, remove them 
numlines=$(wc -l "${output_concretize}" | awk '{print $1}')
numlines=$(($numlines-3))
tail -n ${numlines} ${output_concretize} > "${envpath}/tmp.txt"
mv "${envpath}/tmp.txt" "${output_concretize}"

# now for the first line, get the hash and the spec of the main package 
package_hash=$(head -1 ${output_concretize} | awk '{print $2}')
package_spec=$(head -1 ${output_concretize} | awk '{$1="";$2="";print}')
package_version=$(head -1 ${output_concretize} | sed 's/@/ /'g | sed 's/%/ /g' | awk '{$1="";$2="";print $4}')
modfile="${modpath}/${package}-dependency-set.lua"
cp "${modfilebase}" "${modfile}"

sed -i 's/PACKAGE_SPEC/'"${package_spec}"'/g' "${modfile}"
sed -i 's/PACKAGE_VERSION/'"${package_version}"'/g' "${modfile}"
sed -i 's/PACKAGE_NAME/'"${package}"'/g' "${modfile}"

# now get all the other packages 
for ((i=2;i<${numlines};i++))
do
    hash=$(head -n ${i} ${output_concretize} | tail -n 1 | awk '{print $2}')
    dep=$(head -n ${i} ${output_concretize} | tail -n 1 | awk '{print $3}')
    basemodname=$(spack module lmod find /${hash})
    if [ ! -z "${basemodname}" ]; then
        echo "load(\"${basemodname}\")" >> ${modfile}
    else 
        echo "Dependency module not found! "
        echo "Missing ${dep} with hash ${hash}"
    fi
    basemodname=""
done

rm "${output_concretize}"

# now strip key strings from the modules that are loaded. 
# list of module categories included in variables.sh (sourced above)

for mod_cat in ${module_cat_list}
do
    s="${mod_cat}/"
    sed -i 's:load("'"${s}"':load(":g' "${modfile}"
done

echo "Done updating module for ${package}."
