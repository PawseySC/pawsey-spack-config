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
module load "spack/${spack_ver}"

repo_dir="${PAWSEY_SPACK_CONFIG_REPO:-$(cd "${script_dir}/../../../../.." && pwd)}"
python_env="${repo_dir}/systems/${SYSTEM:-setonix-q}/environments/python"

if should_install_software; then
    spack -e "${python_env}" install --reuse -vvv -j 72 "cutensor@${tool_ver}" "%nvhpc@${nvhpc_ver}"
fi
spack -e "${python_env}" module lmod refresh -y "cutensor@${tool_ver}"

echo "Python environment cutensor ${tool_ver} installation complete."
echo "Expected module: ${cutensor_module}"
