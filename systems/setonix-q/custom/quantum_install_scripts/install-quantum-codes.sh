#!/bin/bash

echo "Installing quantum packages"

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Install Python quantum packages (py-* modules)
packages=(
    qiskit
    pennylane
    pennylane-qiskit
)

for pkg in "${packages[@]}"; do
    echo ""
    echo "========================================"
    echo "Installing ${pkg}"
    echo "========================================"
    if [[ -x "${script_dir}/${pkg}/install.sh" ]]; then
        "${script_dir}/${pkg}/install.sh" "$@"
    else
        echo "Warning: ${script_dir}/${pkg}/install.sh not found or not executable"
    fi
done

echo ""
echo "========================================"
echo "All quantum packages installed!"
echo "========================================"