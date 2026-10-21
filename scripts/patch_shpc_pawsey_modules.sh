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


# Pawsey view names: move entries into <tool>-container, without changing the
# long module files, wrappers or SIF names. Only OpenFOAM versions are shortened
# (e.g. v2606-gcc13... -> v2606), and only when that release has one variant.
# Include earlier installations in the collision check: restore their full tag
# from the symlink target first, then merge new entries and count the variants.
# This also makes repeated patch calls and single-image installs safe. If a new
# variant collides with an existing short name, BOTH entries keep their full tag.
for tool in "${short_dir}/openfoam" "${short_dir}/openfoam-org" "${short_dir}/hpc-python" ; do
  destination="${tool}${shpc_spackuser_container_tag}"
  if [ "${tool##*/}" != "hpc-python" ] && [ -d "$destination" ]; then
    # Restore old short links BEFORE moving new files: a new bare version such
    # as v2606 must not overwrite an old v2606 link pointing at a longer tag.
    for module in "$destination"/*.lua; do
      [ -L "$module" ] || continue
      target=$(readlink -f "$module")
      full_version="${target%/module.lua}"
      full_version="${full_version##*/}"
      if [ "${module##*/}" != "$full_version.lua" ]; then
        mv -- "$module" "$destination/$full_version.lua"
      fi
    done
  fi

  # Move contents rather than the directory, so an existing destination is not
  # nested. SHPC can recreate these original entries when reinstalling an image.
  if [ -d "$tool" ]; then
    mkdir -p "$destination"
    for module in "$tool"/*.lua; do
      [ -e "$module" ] || [ -L "$module" ] || continue
      mv -- "$module" "$destination/"
    done
    rmdir "$tool"
  fi

  if [ "${tool##*/}" != "hpc-python" ] && [ -d "$destination" ]; then
    # Count full-tag entries per release within this OpenFOAM family. The two
    # families are independent, and hpc-python keeps its original version names.
    declare -A release_counts=()
    for module in "$destination"/*.lua; do
      [ -e "$module" ] || [ -L "$module" ] || continue
      version="${module##*/}"; version="${version%.lua}"
      release="${version%%-*}"
      release_counts["$release"]=$(( ${release_counts["$release"]:-0} + 1 ))
    done
    for module in "$destination"/*.lua; do
      [ -e "$module" ] || [ -L "$module" ] || continue
      version="${module##*/}"; version="${version%.lua}"
      release="${version%%-*}"
      if [ "${release_counts["$release"]}" -eq 1 ] && [ "$version" != "$release" ]; then
        mv -- "$module" "$destination/$release.lua"
      fi
    done
    unset release_counts
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
