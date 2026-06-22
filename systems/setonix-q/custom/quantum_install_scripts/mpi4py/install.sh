#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

if [[ -z "${DATE_TAG}" ]]; then
    echo "Error: DATE_TAG not set. Please source settings.sh first."
    exit 1
fi

if should_install_software; then
    echo "Skipping custom ${tool_name}/${tool_ver} installation."
fi

echo "mpi4py ${tool_ver} is installed by systems/${SYSTEM:-setonix-q}/environments/python."
echo "Expected module: ${mpi4py_module}"
