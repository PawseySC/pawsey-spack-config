#!/bin/bash -e

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

if [[ -z "${DATE_TAG}" ]]; then
    echo "Error: DATE_TAG not set. Please source settings.sh first."
    exit 1
fi

module purge
module load pawsey pawseytools "pawseyenv/${DATE_TAG}"
module load PrgEnv-gnu-nvidia
module load "spack/${spack_version}"

repo_dir="${PAWSEY_SPACK_CONFIG_REPO:-$(cd "${script_dir}/../../../../.." && pwd)}"
quantum_env="${repo_dir}/systems/${SYSTEM:-setonix-q}/environments/quantum"

if should_install_software; then
    spack -e "${quantum_env}" install --reuse -vvv -j 72 "cuquantum@${tool_ver}+mpi" "%nvhpc@${nvhpc_ver}"
fi
spack -e "${quantum_env}" module lmod refresh -y "cuquantum@${tool_ver}"

echo "Quantum environment cuQuantum ${tool_ver} installation complete."
echo "Expected module: ${cuquantum_module}"
