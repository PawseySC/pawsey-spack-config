#!/bin/bash -e

# source setup variables
# if copy/pasting these commands, need to run from this directory
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

# This script creates end user singularity modules, starting from the Spack one
# For each version:
# 1. creates 2 pawsey/modules : A. singularity, and B. singularity-astro
#    - to have Singularity available regardless the loaded PrgEng/compiler
#      (works thanks to RPATHs)
#    - to have /astro and /askapbuffer only for astronomers
# 2. hides Spack module in {spack modules}/{arch}/{compiler}
#    - to avoid confusion

# define source (Spack) and destination (Pawsey) directories for Singularity
src_dir="${INSTALL_PREFIX}/modules/${cpu_arch}/gcc/${gcc_version}/utilities/${singularity_name}"
dst_dir="${INSTALL_PREFIX}/${singularity_symlink_module_dir}"

# ensure destination directory exists
mkdir -p ${dst_dir}
# remove old pawsey singularity modules
rm -f ${dst_dir}/*.lua

for version in $( ls ${src_dir}/*.lua ${src_dir}/.*.lua 2>/dev/null ) ; do
  version="${version##*/}"
  version="${version#.}"
  #2. hide Spack module
  if [ -e ${src_dir}/${version} ] ; then
    mv ${src_dir}/${version} ${src_dir}/.${version}
  fi
  # 1.B singularity-askap is just the original module
  cp -p ${src_dir}/.${version} ${dst_dir}/${version/\.lua/-askap.lua}
  # 1.A singularity does not bind mount /askapbuffer
  sed \
    -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
    -e '/singularity_bindpath *=/ s;/astro;;g' \
    ${dst_dir}/${version/\.lua/-astro.lua} \
    >${dst_dir}/${version}-mpi
  # TODO 
  # 1.C singularity does not add any mpi related stuff
  #  >${dst_dir}/${version}-nompi
  # 1.D singularity does not add any thing at all from host 
  #  >${dst_dir}/${version}-nohost
done
