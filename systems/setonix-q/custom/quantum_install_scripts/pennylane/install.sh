#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

echo "Installing ${tool_name}/${tool_ver} with Lightning-GPU/Tensor support"

# Set temporary build directories to user-writable space
export TMPDIR=/scratch/pawsey0001/$USER/tmp
mkdir -p "$TMPDIR"
export TEMP="$TMPDIR"
export TMP="$TMPDIR"

if should_install_software; then

    set_dependencies
    module load "${pip_module}"

    setup_build_dir

    # Prefer GNU MPICH GTL path; enable GPU-aware MPI and disable IPC
    # CRAY_MPICH_DIR and GTL_LIB_PATH are set in use.sh
    GTL_LIB="${GTL_LIB_PATH}/libmpi_gtl_cuda.so"
    echo "Using GTL library path: ${GTL_LIB}"
    if [[ ! -f "${GTL_LIB}" ]]; then
        echo "ERROR: Expected GTL library not found at ${GTL_LIB}"
        echo "Set GTL_LIB_PATH or CRAY_MPICH_DIR to the directory containing libmpi_gtl_cuda.so"
        exit 1
    fi
    export LD_LIBRARY_PATH="${GTL_LIB_PATH}:${LD_LIBRARY_PATH}"
    export CRAY_LD_LIBRARY_PATH="${GTL_LIB_PATH}:${CRAY_LD_LIBRARY_PATH}"
    GTL_LINKER_FLAGS="-L${GTL_LIB_PATH} -lmpi_gtl_cuda -Wl,-rpath,${GTL_LIB_PATH}"
    export LDFLAGS="${GTL_LINKER_FLAGS} ${LDFLAGS}"
    export MPICH_GPU_SUPPORT_ENABLED=1
    export MPICH_GPU_IPC_ENABLED=0

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
    pip install --upgrade "setuptools>=75.8.0"
    pip install cmake ninja build

    CUDA_ARCHES=${CUDA_ARCHES:-90}
    echo "Using CUDA architectures: ${CUDA_ARCHES}"

    export CUQUANTUM_SDK="${CUQUANTUM_ROOT}"
    echo "Using CUQUANTUM_SDK: ${CUQUANTUM_SDK}"
    
    if [[ -n "${CRAY_MPICH_VERSION}" ]]; then
        echo "Cray MPICH detected (${CRAY_MPICH_VERSION}) - enabling GPU-aware MPI"
        export MPICH_GPU_SUPPORT_ENABLED=1
        if [[ -z "$(find ${CRAY_LD_LIBRARY_PATH//:/ } -name 'libmpi_gtl_cuda.so*' 2>/dev/null | head -1)" ]]; then
            echo "Warning: libmpi_gtl_cuda.so not found. Ensure craype-accel-nvidia80 is loaded."
        fi
    fi
    
    echo "Building Lightning-Qubit wheel (OpenMP + BLAS)..."
    PL_BACKEND="lightning_qubit" python scripts/configure_pyproject_toml.py
    CMAKE_ARGS="-DENABLE_OPENMP=ON -DENABLE_BLAS=ON -DLQ_ENABLE_KERNEL_OMP=ON" python -m build --wheel
    cp dist/pennylane_lightning*.whl ${build_dir}/

    echo "Building Lightning-GPU wheel with MPI support..."
    git clean -fdx
    PL_BACKEND="lightning_gpu" python scripts/configure_pyproject_toml.py
    CMAKE_ARGS="-DENABLE_MPI=ON -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHES}" python -m build --wheel || {
        echo "Error: Failed to build lightning-gpu wheel"
        exit 1
    }
    cp dist/pennylane_lightning*.whl ${build_dir}/

    echo "Building Lightning-Tensor wheel..."
    git clean -fdx
    PL_BACKEND="lightning_tensor" python scripts/configure_pyproject_toml.py
    python -m build --wheel || {
        echo "Error: Failed to build lightning-tensor wheel"
        exit 1
    }
    cp dist/pennylane_lightning*.whl ${build_dir}/

    deactivate

    prefix_dir="${install_dir%/lib/*}"
    echo "Installing PennyLane and Lightning packages to ${prefix_dir}..."
    mkdir -p "${prefix_dir}"

    # everything except pennylane-lightning itself
    runtime_requirements=(
        "scipy-openblas32>=0.3.26"
        "networkx"
        "rustworkx>=0.14.0"
        "autograd"
        "appdirs"
        "autoray==0.8.2"
        "cachetools"
        "requests"
        "charset-normalizer<4,>=2"
        "idna<4,>=2.5"
        "urllib3<3,>=1.26"
        "certifi>=2023.5.7"
        "tomlkit"
        "typing_extensions"
        "packaging"
        "diastatic-malt"
        "gast"
        "astunparse"
        "termcolor"
        "wrapt"
        "six"
        "wheel"
    )

    python -m pip install --upgrade pip
    python -m pip install --prefix="${prefix_dir}" --ignore-installed "${runtime_requirements[@]}" || {
        echo "Error: Failed to install PennyLane runtime dependencies"
        exit 1
    }
    python -m pip install --prefix="${prefix_dir}" --no-deps "pennylane==${tool_ver}" ${build_dir}/pennylane_lightning*.whl || {
        echo "Error: Failed to install lightning packages"
        exit 1
    }

    set_permissions "${prefix_dir}"

    cleanup_build
fi

finalize_install

echo "PennyLane ${tool_ver} installation complete. Backends: lightning.gpu, lightning.qubit, lightning.tensor, default.qubit."
