#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

echo ""
echo "========================================================================"
echo "Installing ${tool_name}/${tool_ver} with Lightning-GPU/Tensor support"
echo "========================================================================"

if should_install_software; then
    set_dependencies
    setup_build_dir

    # ========================================================================
    # Set up build environment
    # ========================================================================
    
    python3 -m venv ${build_dir}/venv
    source ${build_dir}/venv/bin/activate

    pip install --upgrade pip

    # ========================================================================
    # Install PennyLane from PyPI
    # ========================================================================
    
    echo "Installing PennyLane ${tool_ver}..."
    mkdir -p "${install_dir}"
    pip install --target="${install_dir}" "pennylane==${tool_ver}" || {
        echo "Error: Failed to install pennylane"
        exit 1
    }

    # ========================================================================
    # Install PennyLane-Lightning-GPU (cuQuantum backend)
    # ========================================================================
    
    echo "Installing PennyLane-Lightning-GPU ${lightning_ver}..."
    pip install --target="${install_dir}" "pennylane-lightning-gpu==${lightning_ver}" || {
        echo "Error: Failed to install pennylane-lightning-gpu"
        exit 1
    }

    # ========================================================================
    # Install PennyLane-Lightning (CPU backend, useful fallback)
    # ========================================================================
    
    echo "Installing PennyLane-Lightning ${lightning_ver}..."
    pip install --target="${install_dir}" "pennylane-lightning==${lightning_ver}" || {
        echo "Warning: Failed to install pennylane-lightning (non-fatal)"
    }

    # ========================================================================
    # Cleanup
    # ========================================================================
    
    deactivate
    cleanup_build
fi

finalize_install

echo ""
echo "========================================================================"
echo "PennyLane ${tool_ver} installation complete!"
echo "========================================================================"
echo ""
echo "Available backends:"
echo "  - lightning.gpu    (CUDA/cuQuantum state-vector simulator)"
echo "  - lightning.qubit  (CPU state-vector simulator)"
echo "  - default.qubit    (NumPy-based simulator)"
echo "========================================================================"
