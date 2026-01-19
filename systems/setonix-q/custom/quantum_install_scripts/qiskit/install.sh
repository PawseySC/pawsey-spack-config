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
    echo "Installing ${tool_name}/${tool_ver} with qiskit-aer/${qiskit_aer_ver}"
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

        echo "Building Qiskit Aer ${qiskit_aer_ver} with CUDA and cuQuantum..."
        cd ${build_dir}/qiskit-aer || exit 1
        
        rm -rf build dist *.egg-info _skbuild

        pip install -r requirements-dev.txt
        pip install "scikit-build>=0.11.0"
        pip install conan==1.65.0
        pip install pybind11==2.13.4
        pip install cmake ninja

        export MPICH_GPU_SUPPORT_ENABLED=1

        GTL_LIB_PATH="${GTL_LIB_PATH:-${cray_mpich_dir_gnu}/gtl/lib}"
        GTL_LIB="${GTL_LIB_PATH}/libmpi_gtl_cuda.so"
        if [[ ! -f "${GTL_LIB}" && -d "${CRAY_MPICH_DIR}" ]]; then
            GTL_LIB="$(find "${CRAY_MPICH_DIR}" -maxdepth 4 -name libmpi_gtl_cuda.so 2>/dev/null | head -1 || true)"
            if [[ -n "${GTL_LIB}" ]]; then
                GTL_LIB_PATH="$(dirname "${GTL_LIB}")"
            fi
        fi
        if [[ -z "${GTL_LIB}" || ! -f "${GTL_LIB}" ]]; then
            FALLBACK_GTL="/opt/cray/pe/mpich/${cray_mpich_ver}/ofi/gnu/${gcc_module_ver}/gtl/lib/libmpi_gtl_cuda.so"
            if [[ -f "${FALLBACK_GTL}" ]]; then
                GTL_LIB="${FALLBACK_GTL}"
                GTL_LIB_PATH="$(dirname "${GTL_LIB}")"
            fi
        fi
        echo "Using GTL library at ${GTL_LIB}"
        if [[ -z "${GTL_LIB}" || ! -f "${GTL_LIB}" ]]; then
            echo "ERROR: Expected GTL library not found. Set GTL_LIB_PATH or CRAY_MPICH_DIR to a path containing libmpi_gtl_cuda.so."
            exit 1
        fi
        GTL_LINKER_FLAGS="-L${GTL_LIB_PATH} -lmpi_gtl_cuda -Wl,-rpath,${GTL_LIB_PATH}"
        export LD_LIBRARY_PATH="${GTL_LIB_PATH}:${LD_LIBRARY_PATH}"

        CUDA_ARCH=${CUDA_ARCH:-90}
        echo "Using CUDA architecture: ${CUDA_ARCH}"
        export CUDAARCHS="${CUDA_ARCH}"

        CMAKE_ARGS=(
            -DAER_THRUST_BACKEND=CUDA
            -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}"
            -DCUQUANTUM_ROOT="${CUQUANTUM_ROOT}"
            -DCUTENSOR_ROOT="${CUTENSOR_ROOT}"
            -DAER_MPI=True
            -DAER_ENABLE_CUQUANTUM=true
            -DAER_LINKER_FLAGS="${GTL_LINKER_FLAGS}"
            -DCMAKE_SHARED_LINKER_FLAGS="${GTL_LINKER_FLAGS}"
            -DCMAKE_MODULE_LINKER_FLAGS="${GTL_LINKER_FLAGS}"
        )

        python ./setup.py bdist_wheel -vvv -- "${CMAKE_ARGS[@]}" --

        echo "Verifying GTL library linkage..."
        CONTROLLER_SO=$(find _skbuild -name "controller_wrappers*.so" 2>/dev/null | head -1)
        if [[ -n "${CONTROLLER_SO}" ]]; then
            if ldd "${CONTROLLER_SO}" | grep -q "libmpi_gtl_cuda"; then
                echo "SUCCESS: GTL library (libmpi_gtl_cuda.so) is linked"
            else
                echo "ERROR: GTL library is NOT linked to ${CONTROLLER_SO}"
                ldd "${CONTROLLER_SO}" | grep -E "mpi|gtl"
                exit 1
            fi
        else
            echo "WARNING: Could not find controller_wrappers.so to verify linkage"
        fi

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
echo "All Qiskit versions installed successfully!"
echo "========================================================================"
