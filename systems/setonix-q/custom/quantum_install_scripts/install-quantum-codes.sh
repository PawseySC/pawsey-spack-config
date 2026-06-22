#!/bin/bash

echo "Installing quantum packages"

# Use unique variable name to avoid being overwritten by sourced scripts
_QUANTUM_INSTALL_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Spack packages installed by this helper.
# cuTENSOR is owned by the python Spack environment and loaded by the quantum packages.
# cuQuantum is owned by the quantum Spack environment.
spack_packages=(
    mpi4py
    cuquantum
)

# Custom NVIDIA libraries still installed outside Spack.
nvidia_packages=()

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
