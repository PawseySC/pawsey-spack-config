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

    export CC=$(which gcc)
    export CXX=$(which g++)

    # Temporary venv for build dependencies only
    python3 -m venv --system-site-packages ${build_dir}/venv
    source ${build_dir}/venv/bin/activate
    pip install --upgrade pip

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

    pip install -r requirements.txt
    pip install cmake ninja build

    export CUQUANTUM_SDK="${CUQUANTUM_ROOT}"
    echo "Using CUQUANTUM_SDK: ${CUQUANTUM_SDK}"
    
    if [[ -n "${CRAY_MPICH_VERSION}" ]]; then
        echo "Cray MPICH detected (${CRAY_MPICH_VERSION}) - enabling GPU-aware MPI"
        export MPICH_GPU_SUPPORT_ENABLED=1
        if [[ -z "$(find ${CRAY_LD_LIBRARY_PATH//:/ } -name 'libmpi_gtl_cuda.so*' 2>/dev/null | head -1)" ]]; then
            echo "Warning: libmpi_gtl_cuda.so not found. Ensure craype-accel-nvidia80 is loaded."
        fi
    fi
    
    echo "Building Lightning-Qubit wheel..."
    PL_BACKEND="lightning_qubit" python scripts/configure_pyproject_toml.py
    python -m build --wheel
    cp dist/pennylane_lightning*.whl ${build_dir}/

    echo "Building Lightning-GPU wheel with MPI support..."
    git clean -fdx
    PL_BACKEND="lightning_gpu" python scripts/configure_pyproject_toml.py
    CMAKE_ARGS="-DENABLE_MPI=ON" python -m build --wheel || {
        echo "Error: Failed to build lightning-gpu wheel"
        exit 1
    }
    cp dist/pennylane_lightning*.whl ${build_dir}/

    prefix_dir="${install_dir%/lib/*}"
    echo "Installing PennyLane and Lightning packages to ${prefix_dir}..."
    mkdir -p "${prefix_dir}"
    
    # Install with --prefix (respects environment, won't reinstall numpy/mpi4py)
    pip install --prefix="${prefix_dir}" "pennylane==${tool_ver}" || {
        echo "Error: Failed to install pennylane"
        exit 1
    }
    
    pip install --prefix="${prefix_dir}" ${build_dir}/pennylane_lightning*.whl || {
        echo "Error: Failed to install lightning packages"
        exit 1
    }
    
    set_permissions "${prefix_dir}"

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
