#!/bin/bash -e

# Clear the module tree once, then restore standalone Python and ReFrame.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

function refresh_module_specs()
{
  local delete_tree=$1
  shift
  local spec

  if ((delete_tree)); then
    spec=$1
    shift
    spack module lmod refresh -y --delete-tree "${spec}"
    echo "Refreshed module for ${spec}"
  fi
  for spec in "$@"; do
    spack module lmod refresh -y "${spec}"
    echo "Refreshed module for ${spec}"
  done
}

if [ "${SYSTEM}" = "setonix-q" ]; then
  python_candidate="${INSTALLATION_METADATA_DIR}/standalone_python_manifest.candidate.json"
  python_plan="${INSTALLATION_METADATA_DIR}/standalone_python_module_plan.tsv"
  standalone_candidate="${INSTALLATION_METADATA_DIR}/standalone_manifest.candidate.json"
  standalone_plan="${INSTALLATION_METADATA_DIR}/standalone_module_plan.tsv"

  "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" assemble \
    --metadata-root "${INSTALLATION_METADATA_DIR}" \
    --output "${python_candidate}" --plan "${python_plan}" \
    --standalone python
  "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" assemble \
    --metadata-root "${INSTALLATION_METADATA_DIR}" \
    --output "${standalone_candidate}" --plan "${standalone_plan}" \
    --standalone python --standalone reframe

  python_specs=()
  declare -A python_spec_set=()
  while IFS=$'\t' read -r hash _rest; do
    [ "${hash}" != "hash" ] || continue
    python_specs+=("/${hash}")
    python_spec_set["${hash}"]=1
  done < "${python_plan}"

  standalone_specs=()
  standalone_roots=()
  reframe_only_specs=()
  while IFS=$'\t' read -r hash role _rest; do
    [ "${hash}" != "hash" ] || continue
    standalone_specs+=("/${hash}")
    if [ "${role}" = "root" ]; then
      standalone_roots+=("/${hash}")
    fi
    if [[ -z ${python_spec_set["${hash}"]+x} ]]; then
      reframe_only_specs+=("/${hash}")
    fi
  done < "${standalone_plan}"

  if ((${#python_specs[@]} == 0 || ${#standalone_roots[@]} == 0 || \
       ${#reframe_only_specs[@]} == 0)); then
    echo "Standalone installation receipts are incomplete."
    exit 1
  fi

  spack mark --implicit "${standalone_specs[@]}"
  spack mark --explicit "${standalone_roots[@]}"

  echo "Regenerating standalone Python modules.."
  refresh_module_specs 1 "${python_specs[@]}"
  echo "Regenerating standalone ReFrame modules.."
  refresh_module_specs 0 "${reframe_only_specs[@]}"
else
  mapfile -t python_specs < <(
    {
      for comp in "${pythoncompilers[@]}"; do
        for arch in "${archs[@]}"; do
          spack find -d -x --format '/{hash}' \
            "python@${python_version}%${comp} target=${arch}"
        done
      done
    } | awk 'NF' | sort -u
  )
  mapfile -t reframe_specs < <(
    spack find -d -x --format '/{hash}' \
      "reframe@${reframe_version}%gcc@${gcc_version}" | awk 'NF' | sort -u
  )
  if ((${#python_specs[@]} == 0 || ${#reframe_specs[@]} == 0)); then
    echo "No installed standalone Python or ReFrame specs found."
    exit 1
  fi
  declare -A python_spec_set=()
  for spec in "${python_specs[@]}"; do python_spec_set["${spec}"]=1; done
  reframe_only_specs=()
  for spec in "${reframe_specs[@]}"; do
    if [[ -z ${python_spec_set["${spec}"]+x} ]]; then
      reframe_only_specs+=("${spec}")
    fi
  done
  echo "Regenerating standalone Python modules.."
  refresh_module_specs 1 "${python_specs[@]}"
  echo "Regenerating standalone ReFrame modules.."
  refresh_module_specs 0 "${reframe_only_specs[@]}"
fi
