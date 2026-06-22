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

if should_install_software; then
    spack install --reuse -vvv -j 72 "cutensor@${tool_ver}" "%nvhpc@${nvhpc_ver}"
fi
spack module lmod refresh -y "cutensor@${tool_ver}"

echo "Spack cutensor ${tool_ver} installation complete."
echo "Expected module: ${cutensor_module}"
