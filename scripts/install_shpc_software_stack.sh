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
# shellcheck disable=SC1090
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"
: "${singularity_name:?Missing singularity_name in settings.sh}"
: "${singularity_version:?Missing singularity_version in settings.sh}"
: "${singularity_mpi_version:?Missing singularity_mpi_version in settings.sh}"

check_singularity_prerequisite() {
    local module_name=$1
    type module >/dev/null 2>&1 || {
        echo "ERROR: Lmod is required to verify ${module_name}." >&2
        exit 1
    }
    if ! module load "$module_name"; then
        echo "ERROR: Required Singularity module is unavailable: ${module_name}" >&2
        exit 1
    fi
}

# SHPC setup now consumes existing Singularity modules; generation/publication
# is intentionally handled by the dedicated Singularity module driver.
echo "Checking Singularity modules required by the configured containers..."
check_singularity_prerequisite "${singularity_name}/${singularity_version}"
if [[ -n "${container_list_mpi//[[:space:]]/}" ]]; then
    check_singularity_prerequisite "${singularity_name}/${singularity_mpi_version}"
fi

echo "Installing shpc..."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc.sh"

echo "Installing containers.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_shpc_containers.sh"

echo "Post installation operations.."
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/post_installation_operations.sh"
