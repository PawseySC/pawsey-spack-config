#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

export TMP=$MYSCRATCH/tmp
export TEMP=$MYSCRATCH/tmp
export TMPDIR=$MYSCRATCH/tmp
mkdir -p "$TMPDIR"

for version_string in "${QISKIT_VERSIONS[@]}"; do
    set_qiskit_version "${version_string}"
    
    echo ""
    echo "========================================================================"
    echo "Installing ${tool_name}/${tool_ver} with qiskit-aer/${qiskit_aer_ver} (no MPI)"
    echo "========================================================================"

    if should_install_software; then

        set_dependencies
        module load py-pip/23.1.2-py3.11.6
        module load py-setuptools/70.1.0-py3.11.6

        setup_build_dir
        
        if [[ ! -d "qiskit-aer" ]]; then
            echo "Cloning qiskit-aer repository..."
            git clone ${qiskit_aer_repo} || {
                echo "Error: Failed to clone qiskit-aer"
                exit 1
            }
        fi

        cd ${build_dir}/qiskit-aer
        git fetch --tags
        git checkout --force ${qiskit_aer_tag} || {
            echo "Error: Failed to checkout qiskit-aer tag ${qiskit_aer_tag}"
            exit 1
        }
        git clean -fdx

        export CC=$(which gcc)
        export CXX=$(which g++)
        export CUDACXX=$(which nvcc)
        export CUDA_PATH="${NVIDIA_PATH}/cuda"

        export CONAN_USER_HOME="${build_dir}/conan"
        mkdir -p "${CONAN_USER_HOME}"

        rm -rf ${build_dir}/venv
        python3 -m venv ${build_dir}/venv
        source ${build_dir}/venv/bin/activate

        pip install --upgrade pip
        
        echo "Installing Qiskit ${tool_ver} from PyPI..."
        mkdir -p "${install_dir}"
        pip install --target="${install_dir}" "qiskit==${tool_ver}" || {
            echo "Error: Failed to install qiskit"
            exit 1
        }

        echo "Building Qiskit Aer ${qiskit_aer_ver} with CUDA and cuQuantum (no MPI)..."
        cd ${build_dir}/qiskit-aer || exit 1
        
        rm -rf build dist *.egg-info _skbuild

        pip install -r requirements-dev.txt
        pip install "scikit-build>=0.11.0"
        pip install conan==1.65.0
        pip install pybind11==2.13.4
        pip install cmake ninja

        CUDA_ARCH=${CUDA_ARCH:-90}
        echo "Using CUDA architecture: ${CUDA_ARCH}"
        export CUDAARCHS="${CUDA_ARCH}"

        CMAKE_ARGS=(
            -DAER_THRUST_BACKEND=CUDA
            -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}"
            -DCUQUANTUM_ROOT="${CUQUANTUM_ROOT}"
            -DCUTENSOR_ROOT="${CUTENSOR_ROOT}"
            -DAER_MPI=False
            -DAER_ENABLE_CUQUANTUM=true
        )

        python ./setup.py bdist_wheel -vvv -- "${CMAKE_ARGS[@]}" --

        pip install --target="${install_dir}" dist/qiskit_aer*.whl || {
            echo "Error: Failed to install qiskit-aer"
            exit 1
        }

        rm -rf "${CONAN_USER_HOME}"
        deactivate
    fi

    finalize_install
    
    echo "${tool_name}/${tool_ver} installation complete!"
done

if should_install_software && [[ -n "${build_dir}" ]]; then
    cleanup_build
fi

echo ""
echo "========================================================================"
echo "All Qiskit (no MPI) versions installed successfully!"
echo "========================================================================"
