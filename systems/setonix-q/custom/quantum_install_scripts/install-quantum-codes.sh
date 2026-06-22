#!/bin/bash

echo "Installing quantum packages"

# Use unique variable name to avoid being overwritten by sourced scripts
_QUANTUM_INSTALL_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Spack-owned prerequisites are installed through the setonix-q environments:
#   python:  py-mpi4py, cutensor, Python stack
#   quantum: cuquantum
# This helper only installs the remaining custom quantum Python packages.

# Python quantum packages (py-* modules)
python_packages=(
    qiskit-nompi
    qiskit
    pennylane
    pennylane-qiskit
)

# Install Python packages
for pkg in "${python_packages[@]}"; do
    echo ""
    echo "========================================"
    echo "Installing ${pkg}"
    echo "========================================"
    if [[ ! -f "${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh" ]]; then
        echo "ERROR: ${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh not found"
        return 1 2>/dev/null || exit 1
    fi
    source "${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh" "$@" || {
        echo "ERROR: Failed to install ${pkg}"
        return 1 2>/dev/null || exit 1
    }
done

echo ""
echo "========================================"
echo "All quantum packages installed successfully!"
echo "========================================"
