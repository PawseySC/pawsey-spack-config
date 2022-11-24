#!/bin/bash

# source setup variables
# if copy/pasting these commands, need to run from this directory
script_dir="$(readlink -f "$(dirname $0 2>/dev/null)" || readlink -f "$(pwd)")"
. ${script_dir}/variables.sh

# define source and destination directories for container modulefiles
long_dir="${INSTALL_PREFIX}/${shpc_containers_modules_dir_long}"
short_dir="${INSTALL_PREFIX}/${shpc_containers_modules_dir}"

# sif directory (for Openfoam SIF symlinkst)
sif_dir="${INSTALL_PREFIX}/${shpc_containers_dir}"
# target directory for Openfoam SIF symlinks
of_dir="${INSTALL_PREFIX}/${containers_root_dir}/openfoam-sif"
# create it
mkdir -p ${of_dir}


# Pawsey only - add -container suffix to tool directories
for tool in ${short_dir}/openfoam ${short_dir}/openfoam-org ${short_dir}/hpc-python ; do
  if [ -d ${tool} ] ; then
    mv ${tool} ${tool}${shpc_spackuser_container_tag}
  fi
done

# Openfoam only - fix conflict line in modulefile, it is too long
for tool in ${long_dir}/quay.io/pawsey/openfoam* ; do
  for module in ${tool}/*/module.lua ; do
    if [ -e ${module} ] ; then
      new_conflict="conflict(\"${tool##*/}${shpc_spackuser_container_tag}\")"
      sed -i '/conflict(/c '"${new_conflict}"'' ${module}
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
