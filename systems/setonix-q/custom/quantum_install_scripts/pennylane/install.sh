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
    
    # Force GCC for builds
    export CC=$(which gcc)
    export CXX=$(which g++)

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
    # Clone and build PennyLane-Lightning-GPU from source
    # This allows us to use our cuQuantum and enable MPI support
    # ========================================================================
    
    echo "Cloning pennylane-lightning ${lightning_ver}..."
    if [[ ! -d "pennylane-lightning" ]]; then
        git clone https://github.com/PennyLaneAI/pennylane-lightning.git || {
            echo "Error: Failed to clone pennylane-lightning"
            exit 1
        }
    fi
    
    cd ${build_dir}/pennylane-lightning
    git fetch --tags
    git checkout --force v${lightning_ver} || {
        echo "Error: Failed to checkout pennylane-lightning v${lightning_ver}"
        exit 1
    }
    git clean -fdx

    # Install build requirements
    pip install -r requirements.txt
    pip install cmake ninja

    # Set CUQUANTUM_SDK environment variable - this is how pennylane-lightning finds cuQuantum
    # The CMake build uses find_library to search CUQUANTUM_SDK/lib for custatevec
    export CUQUANTUM_SDK="${CUQUANTUM_ROOT}"
    
    echo "Using CUQUANTUM_SDK: ${CUQUANTUM_SDK}"
    
    # On Cray systems with CUDA, the build requires libmpi_gtl_cuda.so (GPU Transport Layer)
    # This should be in CRAY_LD_LIBRARY_PATH when cray-mpich is loaded
    if [[ -n "${CRAY_MPICH_VERSION}" ]]; then
        echo "Cray MPICH detected (${CRAY_MPICH_VERSION}) - enabling GPU-aware MPI"
        export MPICH_GPU_SUPPORT_ENABLED=1
        if [[ -z "$(find ${CRAY_LD_LIBRARY_PATH//:/ } -name 'libmpi_gtl_cuda.so*' 2>/dev/null | head -1)" ]]; then
            echo "Warning: libmpi_gtl_cuda.so not found in CRAY_LD_LIBRARY_PATH"
            echo "         MPI build may fail. Ensure craype-accel-nvidia80 or similar is loaded."
        fi
    fi
    
    echo "Building Lightning-Qubit (required dependency)..."
    PL_BACKEND="lightning_qubit" python scripts/configure_pyproject_toml.py
    pip install . -vv

    echo "Building Lightning-GPU with MPI support..."
    git clean -fdx
    PL_BACKEND="lightning_gpu" python scripts/configure_pyproject_toml.py
    # ENABLE_MPI=ON enables MPI support; CMake uses find_package(MPI) for discovery
    CMAKE_ARGS="-DENABLE_MPI=ON" pip install . -vv || {
        echo "Error: Failed to build lightning-gpu"
        exit 1
    }

    # Install the built packages to target directory
    pip install --target="${install_dir}" --upgrade pennylane-lightning pennylane-lightning-gpu || {
        echo "Error: Failed to install lightning packages to target"
        exit 1
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
echo "  - lightning.gpu    (CUDA/cuQuantum state-vector simulator with MPI)"
echo "  - lightning.qubit  (CPU state-vector simulator)"
echo "  - default.qubit    (NumPy-based simulator)"
echo "========================================================================"
