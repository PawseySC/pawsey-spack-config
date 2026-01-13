#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

if should_install_software; then
    echo "Installing ${tool_name}/${tool_ver}"
    set_dependencies
    setup_build_dir

    if [[ ! -d "qiskit-aer" ]]; then
        git clone --depth 1 --branch ${qiskit_aer_tag} ${qiskit_aer_repo} || {
            echo "Error: Failed to clone qiskit-aer tag ${qiskit_aer_tag}"
            exit 1
        }
    fi

    cd qiskit-aer || exit 1

    # Force GCC for all builds (avoid Cray wrappers picking up nvc)
    export CC=$(which gcc)
    export CXX=$(which g++)
    export CUDACXX=$(which nvcc)

    # Set CUDA_PATH for CMake (from NVHPC)
    export CUDA_PATH="${NVIDIA_PATH}/cuda"

    # Conan home for build dependencies
    export CONAN_USER_HOME="${build_dir}/conan"
    mkdir -p "${CONAN_USER_HOME}"

    python3 -m venv ${build_dir}/venv
    source ${build_dir}/venv/bin/activate

    pip install --upgrade pip
    pip install -r requirements-dev.txt
    # Build tools not available as modules
    pip install --force-reinstall "scikit-build>=0.11.0"
    pip install --force-reinstall conan==1.65.0
    pip install --force-reinstall pybind11==2.13.4
    pip install cmake ninja
    # numpy, scipy, cython, mpi4py, setuptools loaded as modules

    echo "Building with CUDA and cuQuantum..."
    python ./setup.py bdist_wheel -vvv -- \
        -DAER_THRUST_BACKEND=CUDA \
        -DCUQUANTUM_ROOT="${CUQUANTUM_ROOT}" \
        -DCUTENSOR_ROOT="${CUTENSOR_ROOT}" \
        -DAER_MPI=True \
        -DAER_ENABLE_CUQUANTUM=true \
        --

    rm -rf "${CONAN_USER_HOME}"

    mkdir -p "${install_dir}"
    pip install --target="${install_dir}" dist/qiskit_aer*.whl

    deactivate
    cleanup_build
fi

finalize_install
