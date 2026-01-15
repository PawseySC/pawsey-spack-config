#!/bin/bash

echo "Installing quantum packages"

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# NVIDIA libraries (must be installed first as dependencies)
nvidia_packages=(
    cutensor
    cuquantum
)

# Python quantum packages (py-* modules)
python_packages=(
    qiskit
    pennylane
    pennylane-qiskit
)

# Install NVIDIA libraries first
for pkg in "${nvidia_packages[@]}"; do
    echo ""
    echo "========================================"
    echo "Installing ${pkg}"
    echo "========================================"
    if [[ -f "${script_dir}/${pkg}/install.sh" ]]; then
        source "${script_dir}/${pkg}/install.sh" "$@"
    else
        echo "Warning: ${script_dir}/${pkg}/install.sh not found"
    fi
done

# Install Python packages
for pkg in "${python_packages[@]}"; do
    echo ""
    echo "========================================"
    echo "Installing ${pkg}"
    echo "========================================"
    if [[ -f "${script_dir}/${pkg}/install.sh" ]]; then
        source "${script_dir}/${pkg}/install.sh" "$@"
    else
        echo "Warning: ${script_dir}/${pkg}/install.sh not found"
    fi
done

echo ""
echo "========================================"
echo "All quantum packages installed!"
echo "========================================"