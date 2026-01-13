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

    python3 -m venv ${build_dir}/venv
    source ${build_dir}/venv/bin/activate

    pip install --upgrade pip
    pip install -r requirements-dev.txt
    pip install scikit-build cmake ninja pybind11

    echo "Building with CUDA and cuQuantum..."
    python ./setup.py bdist_wheel -- \
        -DCMAKE_C_COMPILER=gcc \
        -DCMAKE_CXX_COMPILER=g++ \
        -DAER_THRUST_BACKEND=CUDA \
        -DAER_ENABLE_CUQUANTUM=true \
        -DCUQUANTUM_ROOT="${CUQUANTUM_ROOT}" \
        -DCUTENSOR_ROOT="${CUTENSOR_ROOT}" \
        -DAER_MPI=True \
        -DAER_DISABLE_GDR=True \
        -- -j$(nproc)

    mkdir -p "${install_dir}"
    pip install --target="${install_dir}" dist/qiskit_aer*.whl

    deactivate
    cleanup_build
fi

finalize_install
