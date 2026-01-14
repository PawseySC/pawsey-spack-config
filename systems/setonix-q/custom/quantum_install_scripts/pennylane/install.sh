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

    # Create venv with system site-packages to use numpy/scipy/mpi4py from modules
    python3 -m venv --system-site-packages ${build_dir}/venv
    source ${build_dir}/venv/bin/activate

    pip install --upgrade pip

    # ========================================================================
    # Clone and build PennyLane-Lightning-GPU from source FIRST
    # This allows us to use our cuQuantum and enable MPI support
    # We build lightning first, then install pennylane with --no-deps to avoid
    # pulling the pre-built lightning from PyPI
    # ========================================================================
    
    mkdir -p "${install_dir}"
    cd ${build_dir}
    
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
    pip install cmake ninja build

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
    
    # Build Lightning-Qubit wheel (required dependency for lightning-gpu)
    echo "Building Lightning-Qubit wheel..."
    PL_BACKEND="lightning_qubit" python scripts/configure_pyproject_toml.py
    python -m build --wheel
    cp dist/pennylane_lightning*.whl ${build_dir}/
    
    # Install lightning-qubit to venv (needed as build dependency for lightning-gpu)
    pip install dist/pennylane_lightning*.whl

    # Build Lightning-GPU wheel with MPI support
    echo "Building Lightning-GPU wheel with MPI support..."
    git clean -fdx
    PL_BACKEND="lightning_gpu" python scripts/configure_pyproject_toml.py
    CMAKE_ARGS="-DENABLE_MPI=ON" python -m build --wheel || {
        echo "Error: Failed to build lightning-gpu wheel"
        exit 1
    }
    cp dist/pennylane_lightning*.whl ${build_dir}/

    # ========================================================================
    # Install all packages to target directory
    # ========================================================================
    
    echo "Installing PennyLane and Lightning packages to ${install_dir}..."
    
    # Install pennylane WITHOUT its dependencies (we provide them via modules)
    # This avoids pulling the pre-built pennylane-lightning from PyPI
    pip install --target="${install_dir}" --no-deps "pennylane==${tool_ver}" || {
        echo "Error: Failed to install pennylane"
        exit 1
    }
    
    # Install pennylane's other PyPI dependencies (excluding pennylane-lightning)
    pip install --target="${install_dir}" \
        networkx rustworkx autograd appdirs "autoray==0.8.2" \
        cachetools requests tomlkit typing_extensions packaging diastatic-malt || {
        echo "Error: Failed to install pennylane dependencies"
        exit 1
    }
    
    # Install our custom-built lightning wheels
    pip install --target="${install_dir}" --no-deps ${build_dir}/pennylane_lightning*.whl || {
        echo "Error: Failed to install lightning packages"
        exit 1
    }
    
    # Set proper permissions on installed files
    set_permissions "${install_dir}"

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
