#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

echo "Installing ${tool_name}/${plugin_ver} for Qiskit ${qiskit_ver} and PennyLane ${pennylane_ver}"

if should_install_software; then
    set_dependencies
    module load "${pip_module}"

    setup_build_dir

    python -m pip install --upgrade pip
    mkdir -p "${install_dir}"

    # Install dependencies that are unique to the plugin without letting pip
    # replace our module-provided Qiskit, Qiskit Aer, or PennyLane installs.
    python -m pip install --prefix="${install_dir%/lib/*}" \
        "sympy" \
        "networkx>=2.2" \
        "requests>=2.19" \
        "requests-ntlm>=1.1.0" \
        "urllib3>=1.21.1" \
        "python-dateutil>=2.8.0" \
        "ibm-platform-services>=0.22.6" \
        "pydantic>=2.5.0" \
        "packaging" || {
        echo "Error: Failed to install pennylane-qiskit runtime dependencies"
        exit 1
    }

    python -m pip install --prefix="${install_dir%/lib/*}" --no-deps \
        "qiskit-ibm-runtime~=0.43.0" \
        "pennylane-qiskit==${plugin_ver}" || {
        echo "Error: Failed to install pennylane-qiskit ${plugin_ver}"
        exit 1
    }

    set_permissions "${install_dir%/lib/*}"
    cleanup_build
fi

finalize_install module.lua

echo "pennylane-qiskit ${plugin_ver} installation complete for Qiskit ${qiskit_ver}"
