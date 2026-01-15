#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

echo "Installing ${tool_name}/${plugin_ver} for Qiskit ${qiskit_ver} and PennyLane ${pennylane_ver}"

if should_install_software; then
    set_dependencies
    setup_build_dir

    python3 -m venv --system-site-packages ${build_dir}/venv
    source ${build_dir}/venv/bin/activate
    pip install --upgrade pip

    mkdir -p "${install_dir}"
    python -m pip install --prefix="${install_dir%/lib/*}" --no-binary=:all: \
        "pennylane-qiskit==${plugin_ver}" || {
        echo "Error: Failed to install pennylane-qiskit ${plugin_ver}"
        exit 1
    }

    deactivate
    set_permissions "${install_dir%/lib/*}"
    cleanup_build
fi

finalize_install module.lua

echo "pennylane-qiskit ${plugin_ver} installation complete for Qiskit ${qiskit_ver}"
