#!/bin/bash

echo "Installing quantum packages"

# Use unique variable name to avoid being overwritten by sourced scripts
_QUANTUM_INSTALL_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Spack packages (installed first, generates its own module)
spack_packages=(
    mpi4py
)

# NVIDIA libraries (must be installed before Python packages)
nvidia_packages=(
    cutensor
    cuquantum
)

# Python quantum packages (py-* modules)
python_packages=(
    qiskit-nompi
    qiskit
    pennylane
    pennylane-qiskit
)

# Install spack packages first
for pkg in "${spack_packages[@]}"; do
    echo ""
    echo "========================================"
    echo "Installing ${pkg}"
    echo "========================================"
    if [[ ! -f "${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh" ]]; then
        echo "ERROR: ${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh not found"
        return 1 2>/dev/null || exit 1
    fi
    bash "${_QUANTUM_INSTALL_DIR}/${pkg}/install.sh" "$@" || {
        echo "ERROR: Failed to install ${pkg}"
        return 1 2>/dev/null || exit 1
    }
done

# Install NVIDIA libraries
for pkg in "${nvidia_packages[@]}"; do
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