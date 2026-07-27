#!/bin/bash -e

# Publish modules and the installation manifest from the concrete specs that
# were actually installed by the Setonix-Q workflow.

set -o pipefail

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

if [ "${SYSTEM}" != "setonix-q" ]; then
  echo "Installation manifests are currently enabled only for setonix-q."
  exit 1
fi
if (($# == 0)); then
  echo "Usage: $0 ENVIRONMENT [ENVIRONMENT ...]"
  exit 1
fi

. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

candidate="${INSTALLATION_METADATA_DIR}/spack_install_manifest.candidate.json"
plan="${INSTALLATION_METADATA_DIR}/spack_install_module_plan.tsv"
assemble_args=(
  assemble
  --metadata-root "${INSTALLATION_METADATA_DIR}"
  --output "${candidate}"
  --plan "${plan}"
  --standalone python
  --standalone reframe
)
for env in "$@"; do
  assemble_args+=(--environment "${env}")
done
"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" "${assemble_args[@]}"

active_specs=()
public_specs=()
environment_specs=()
while IFS=$'\t' read -r hash role standalone standalone_root environment environment_root; do
  [ "${hash}" != "hash" ] || continue
  spec="/${hash}"
  active_specs+=("${spec}")
  if [ "${role}" = "root" ]; then
    public_specs+=("${spec}")
  fi
  # Standalone modules already exist. Refresh a shared hash only when an
  # environment promotes a standalone dependency to a public root.
  if [ "${environment}" = 1 ] && \
     { [ "${standalone}" = 0 ] || { [ "${environment_root}" = 1 ] && [ "${standalone_root}" = 0 ]; }; }; then
    environment_specs+=("${spec}")
  fi
done < "${plan}"

if ((${#active_specs[@]} == 0 || ${#public_specs[@]} == 0)); then
  echo "The Setonix-Q installation manifest contains no installed specs or roots."
  exit 1
fi

if [ "${SPACK_POPULATE_CACHE}" -eq 1 ]; then
  for spec in "${public_specs[@]}"; do
    spack buildcache create -a -m systemwide_buildcache "${spec}"
  done
fi

# hide_implicits and dependency autoload names use these database flags.
spack mark --implicit "${active_specs[@]}"
spack mark --explicit "${public_specs[@]}"

for spec in "${environment_specs[@]}"; do
  spack module lmod refresh -y "${spec}"
  echo "Refreshed module for ${spec}"
done

annotations=$(mktemp "${INSTALLATION_METADATA_DIR}/.module-annotations.XXXXXX.tsv")
trap 'rm -f "${annotations}"' EXIT
for spec in "${active_specs[@]}"; do
  hash=${spec#/}
  prefix=$(spack find --format '{prefix}' "${spec}" | awk 'NF {print; exit}')
  module_name=$(spack module lmod find "${spec}")
  module_path=$(spack module lmod find --full-path "${spec}")
  if [ -z "${prefix}" ] || [ -z "${module_name}" ] || \
     [ -z "${module_path}" ] || [ ! -d "${prefix}" ] || [ ! -f "${module_path}" ]; then
    echo "Could not resolve installed/module metadata for ${spec}."
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\n' \
    "${hash}" "${prefix}" "${module_name}" "${module_path}" >> "${annotations}"
done

"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" publish \
  --metadata-root "${INSTALLATION_METADATA_DIR}" \
  --candidate "${candidate}" \
  --annotations "${annotations}" \
  --output "${SPACK_INSTALL_MANIFEST}"

echo "Published Setonix-Q installation manifest: ${SPACK_INSTALL_MANIFEST}"
