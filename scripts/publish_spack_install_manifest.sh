#!/bin/bash -e

# Assemble the receipts for the requested environments, reconcile Spack's
# explicit/implicit metadata, append their modules to the existing tree, and
# atomically publish the durable installation manifest.

set -o pipefail

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

if (($# == 0)); then
  echo "Usage: $0 ENVIRONMENT [ENVIRONMENT ...]"
  exit 1
fi

deployment_environments=("$@")
manifest_candidate="${INSTALLATION_METADATA_DIR}/spack_install_manifest.candidate.json"
assemble_args=(
  assemble
  --metadata-root "${INSTALLATION_METADATA_DIR}"
  --output "${manifest_candidate}"
  --standalone python
  --standalone reframe
)
for env in "${deployment_environments[@]}"; do
  assemble_args+=(--environment "${env}")
done
"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" "${assemble_args[@]}"

active_module_specs=()
public_root_module_specs=()
environment_dependency_module_specs=()
environment_root_module_specs=()
standalone_module_specs=()
standalone_root_module_specs=()
load_spack_install_manifest_hashes "${manifest_candidate}" all \
  active_module_specs
load_spack_install_manifest_hashes "${manifest_candidate}" public-root \
  public_root_module_specs
load_spack_install_manifest_hashes "${manifest_candidate}" environment-dependency \
  environment_dependency_module_specs
load_spack_install_manifest_hashes "${manifest_candidate}" environment-root \
  environment_root_module_specs
load_spack_install_manifest_hashes "${manifest_candidate}" standalone-all \
  standalone_module_specs
load_spack_install_manifest_hashes "${manifest_candidate}" standalone-root \
  standalone_root_module_specs

if ((${#active_module_specs[@]} == 0 || ${#public_root_module_specs[@]} == 0)); then
  echo "The installation manifest contains no active installed specs or public roots."
  exit 1
fi

# Build caches from active, recorded roots rather than every globally explicit
# DB entry, which may include software retained from an earlier deployment.
echo "Creating buildcache for installed packages, module refresh ... "
if [ "${SPACK_POPULATE_CACHE}" -eq 1 ]; then
  for module_spec in "${public_root_module_specs[@]}"; do
    spack buildcache create -a -m systemwide_buildcache "${module_spec}"
  done
fi

# hide_implicits and autoload layout both consult the global DB flag. Normalize
# only the active manifest DAG, then let a root in any source win globally.
spack mark --implicit "${active_module_specs[@]}"
spack mark --explicit "${public_root_module_specs[@]}"

declare -A standalone_module_spec_set=()
declare -A standalone_root_module_spec_set=()
for module_spec in "${standalone_module_specs[@]}"; do
  standalone_module_spec_set["${module_spec}"]=1
done
for module_spec in "${standalone_root_module_specs[@]}"; do
  standalone_root_module_spec_set["${module_spec}"]=1
done

# Standalone-only hashes were generated before environment installation and are
# left untouched here. A standalone dependency that is an environment root is
# deliberately promoted and refreshed with its public name.
environment_module_specs=()
for module_spec in "${environment_dependency_module_specs[@]}"; do
  if [[ -z ${standalone_module_spec_set["${module_spec}"]+x} ]]; then
    environment_module_specs+=("${module_spec}")
  fi
done
for module_spec in "${environment_root_module_specs[@]}"; do
  if [[ -z ${standalone_root_module_spec_set["${module_spec}"]+x} ]]; then
    environment_module_specs+=("${module_spec}")
  fi
done

if ((${#environment_module_specs[@]} > 0)); then
  echo "Refreshing modules from the actual deployment manifest.."
  for module_spec in "${environment_module_specs[@]}"; do
    spack module lmod refresh -y "${module_spec}"
    echo "Refreshed module for ${module_spec}"
  done
else
  echo "No additional environment modules require regeneration."
fi

# Record the canonical module name/path and installed prefix selected by Spack.
# ReFrame and operators can consume exact published metadata instead of
# reproducing Spack's projection and module naming rules independently.
module_annotations=$(mktemp "${INSTALLATION_METADATA_DIR}/.module-annotations.XXXXXX.tsv")
trap 'rm -f "${module_annotations}"' EXIT
for module_spec in "${active_module_specs[@]}"; do
  module_hash=${module_spec#/}
  install_path=$(spack find --format '{prefix}' "${module_spec}" | awk 'NF {print; exit}')
  module_use_name=$(spack module lmod find "${module_spec}")
  module_path=$(spack module lmod find --full-path "${module_spec}")
  if [ -z "${install_path}" ] || [ -z "${module_use_name}" ] || \
     [ -z "${module_path}" ] || [ ! -f "${module_path}" ]; then
    echo "Could not resolve installed/module metadata for ${module_spec}."
    rm -f "${module_annotations}"
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\n' \
    "${module_hash}" "${install_path}" "${module_use_name}" "${module_path}" \
    >> "${module_annotations}"
done

"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" annotate \
  --manifest "${manifest_candidate}" \
  --annotations "${module_annotations}"
rm -f "${module_annotations}"
trap - EXIT

"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" publish \
  --manifest "${manifest_candidate}" \
  --output "${SPACK_INSTALL_MANIFEST}" \
  --check-paths
echo "Published Spack installation manifest: ${SPACK_INSTALL_MANIFEST}"
