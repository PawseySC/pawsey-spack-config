#!/bin/bash -e

# Rebuild standalone Python and ReFrame modules before installing deployment
# environments. This is the only module refresh that deletes the existing tree,
# removing stale modules while restoring essential tools early.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch

. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

function refresh_standalone_module_specs()
{
  local delete_tree=$1
  shift
  local module_spec

  if ((delete_tree)); then
    module_spec=$1
    shift
    spack module lmod refresh -y --delete-tree "${module_spec}"
    echo "Refreshed module for ${module_spec}"
  fi

  for module_spec in "$@"; do
    spack module lmod refresh -y "${module_spec}"
    echo "Refreshed module for ${module_spec}"
  done
}

# Build a candidate index from the exact concrete specs used for the standalone
# installations.  This avoids rediscovering them through global DB explicitness
# and validates both receipts before the one destructive module-tree clear.
python_manifest_candidate="${INSTALLATION_METADATA_DIR}/standalone_python_manifest.candidate.json"
standalone_manifest_candidate="${INSTALLATION_METADATA_DIR}/standalone_manifest.candidate.json"
"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" assemble \
  --metadata-root "${INSTALLATION_METADATA_DIR}" \
  --output "${python_manifest_candidate}" \
  --standalone python
"${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" assemble \
  --metadata-root "${INSTALLATION_METADATA_DIR}" \
  --output "${standalone_manifest_candidate}" \
  --standalone python \
  --standalone reframe

standalone_all_module_specs=()
standalone_root_module_specs=()
standalone_dependency_module_specs=()
python_root_module_specs=()
python_dependency_module_specs=()
load_spack_install_manifest_hashes "${standalone_manifest_candidate}" all \
  standalone_all_module_specs
load_spack_install_manifest_hashes "${standalone_manifest_candidate}" public-root \
  standalone_root_module_specs
load_spack_install_manifest_hashes "${standalone_manifest_candidate}" dependency \
  standalone_dependency_module_specs
load_spack_install_manifest_hashes "${python_manifest_candidate}" public-root \
  python_root_module_specs
load_spack_install_manifest_hashes "${python_manifest_candidate}" dependency \
  python_dependency_module_specs

if ((${#standalone_all_module_specs[@]} == 0 || \
     ${#standalone_root_module_specs[@]} == 0 || \
     ${#python_root_module_specs[@]} == 0)); then
  echo "Standalone installation receipts contain no installed Python/ReFrame roots."
  exit 1
fi

# Spack's Lmod writer derives both the current module name and autoloaded
# dependency names from these DB flags.  Reset only the active standalone DAG,
# then restore its true roots.
spack mark --implicit "${standalone_all_module_specs[@]}"
spack mark --explicit "${standalone_root_module_specs[@]}"

python_module_specs=(
  "${python_dependency_module_specs[@]}"
  "${python_root_module_specs[@]}"
)

declare -A python_module_spec_set=()
for module_spec in "${python_module_specs[@]}"; do
  python_module_spec_set["${module_spec}"]=1
done

reframe_only_module_specs=()
for module_spec in \
  "${standalone_dependency_module_specs[@]}" \
  "${standalone_root_module_specs[@]}"; do
  if [[ -z ${python_module_spec_set["${module_spec}"]+x} ]]; then
    reframe_only_module_specs+=("${module_spec}")
  fi
done

if ((${#reframe_only_module_specs[@]} == 0)); then
  echo "No ReFrame-specific specs found in the standalone receipts."
  exit 1
fi

echo "Regenerating standalone Python modules.."
refresh_standalone_module_specs 1 "${python_module_specs[@]}"

echo "Regenerating standalone ReFrame modules.."
refresh_standalone_module_specs 0 "${reframe_only_module_specs[@]}"
