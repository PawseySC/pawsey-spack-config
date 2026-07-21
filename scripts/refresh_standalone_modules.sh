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

# Resolve and validate both standalone DAGs before deleting existing modules.
# Generate Python first because Spack and ReFrame depend on it.
mapfile -t python_module_specs < <(
  {
    for comp in "${pythoncompilers[@]}"; do
      for arch in "${archs[@]}"; do
        spack find -d -x --format '/{hash}' \
          "python@${python_version}%${comp} target=${arch}"
      done
    done
  } | sort -u
)

if ((${#python_module_specs[@]} == 0)); then
  echo "No installed standalone Python specs found for module generation."
  exit 1
fi

mapfile -t reframe_module_specs < <(
  spack find -d -x --format '/{hash}' \
    "reframe@${reframe_version}%gcc@${gcc_version}" | sort -u
)

if ((${#reframe_module_specs[@]} == 0)); then
  echo "No installed standalone ReFrame specs found for module generation."
  exit 1
fi

# Python's DAG is complete, so only append ReFrame hashes not already generated.
# This keeps the Python modules intact if ReFrame refresh fails.
declare -A python_module_spec_set=()
for module_spec in "${python_module_specs[@]}"; do
  python_module_spec_set["${module_spec}"]=1
done

reframe_only_module_specs=()
for module_spec in "${reframe_module_specs[@]}"; do
  if [[ -z ${python_module_spec_set["${module_spec}"]+x} ]]; then
    reframe_only_module_specs+=("${module_spec}")
  fi
done

if ((${#reframe_only_module_specs[@]} == 0)); then
  echo "No ReFrame-specific specs found for module generation."
  exit 1
fi

echo "Regenerating standalone Python modules.."
refresh_standalone_module_specs 1 "${python_module_specs[@]}"

echo "Regenerating standalone ReFrame modules.."
refresh_standalone_module_specs 0 "${reframe_only_module_specs[@]}"
