#!/bin/bash -e

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

# define source and destination directories for container modulefiles
long_dir="${INSTALL_PREFIX}/${shpc_containers_modules_dir_long}"
short_dir="${INSTALL_PREFIX}/${shpc_containers_modules_dir}"

# sif directory (for Openfoam SIF symlinkst)
sif_dir="${INSTALL_PREFIX}/${shpc_containers_dir}"
# target directory for Openfoam SIF symlinks
of_dir="${INSTALL_PREFIX}/${containers_root_dir}/openfoam-sif"
# create it
mkdir -p "${of_dir}"


# Pawsey only - move module files in ${tool} dirs to a directory with name ${tool}-container
#  Contents are moved instead of renaming ${tool} dir in order to avoid nesting of directories when
#   the ${tool}-container directory already exists
for tool in "${short_dir}/openfoam" "${short_dir}/openfoam-org" "${short_dir}/hpc-python" ; do
  if [ -d ${tool} ] ; then
    mkdir -p ${tool}${shpc_spackuser_container_tag}
    for module in ${tool}/*.lua ; do
      mv ${module} ${tool}${shpc_spackuser_container_tag}
    done
    rmdir $tool
  fi
done

# Openfoam only - fix conflict line in modulefile, it is too long
for tool in ${long_dir}/quay.io/pawsey/openfoam* ; do
  for module in ${tool}/*/module.lua ; do
    if [ -e ${module} ] ; then
      new_conflict="conflict(\"${tool##*/}${shpc_spackuser_container_tag}\")"
      sed --follow-symlinks -i '/conflict(/c '"${new_conflict}"'' ${module}
      chmod u=rw,go=r ${module} #Recovering the right permissions after sed command
    fi
  done
done

# Openfoam only - add symlink to SIF image
for tool in ${sif_dir}/quay.io/pawsey/openfoam* ; do
  for version in ${tool}/* ; do
    src_sif="${version}/quay.io-pawsey-${tool##*/}-${version##*/}-sha256*.sif"
    dst_sif="${of_dir}/${tool##*/}_${version##*/}.sif"
    if [ -e ${src_sif} ] ; then
      rm -f ${dst_sif}
      ln -s ${src_sif} ${dst_sif}
    fi
  done
done

# Applying trick in tensorflow and pytorch modules to avoid problems with PYTHONSTARTUP variable
# See ticket GS-32800 and its parent GS-31936
# 1) Creating the directory that will contain auxiliary files
patch_dir="${INSTALL_PREFIX}/pawsey/lmod-variable-fixes"
mkdir -p ${patch_dir}
# Copying the file with the LMOD logic to cancel PYTHONSTARTUP variable when loading the modules
cp "${PAWSEY_SPACK_CONFIG_REPO}/scripts/_fixPYTHONSTARTUP.lua" ${patch_dir}

# 2) Adding into the module.lua files the call for the logic to cancel PYTHONSTARTUP
for tool in ${long_dir}/quay.io/pawsey/tensorflow* ${long_dir}/quay.io/pawsey/pytorch*; do
  for module in ${tool}/*/module.lua ; do
    if [ -e ${module} ] ; then  
      cat << EOF >> ${module}

-- Fixing problems with PYTHONSTARTUP when using python inside the containers
-- See ticket GS-32800 and its parent GS-31936

local patch_dir = "${INSTALL_PREFIX}/pawsey/lmod-variable-fixes"
local patch_file = patch_dir .. "/_fixPYTHONSTARTUP.lua"
local func = assert(loadfile(patch_file))
func()
EOF
    fi
  done
done
