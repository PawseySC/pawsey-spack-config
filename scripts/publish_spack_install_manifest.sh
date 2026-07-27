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
while IFS=$'\t' read -r hash name version role standalone standalone_root environment environment_root; do
  [ "${hash}" != "hash" ] || continue
  spec="/${hash}"
  active_specs+=("${spec}")
  if [ "${role}" = "root" ]; then
    public_specs+=("${spec}")
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

annotations=$(mktemp "${INSTALLATION_METADATA_DIR}/.module-annotations.XXXXXX.tsv")
trap 'rm -f "${annotations}"' EXIT
# This single Spack process updates explicit flags, regenerates environment
# modules from the plan, then records the exact paths it generated.
spack python "$(spack_install_manifest_tool)" annotate-modules \
  --plan "${plan}" --output "${annotations}"

"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" publish \
  --metadata-root "${INSTALLATION_METADATA_DIR}" \
  --candidate "${candidate}" \
  --annotations "${annotations}" \
  --output "${SPACK_INSTALL_MANIFEST}"

echo "Published Setonix-Q installation manifest: ${SPACK_INSTALL_MANIFEST}"
