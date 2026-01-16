#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

# ============================================================================
# Install each Qiskit version
# ============================================================================

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

        # ====================================================================
        # Clone qiskit-aer repository (qiskit installed from PyPI)
        # ====================================================================
        
        if [[ ! -d "qiskit-aer" ]]; then
            echo "Cloning qiskit-aer repository..."
            git clone ${qiskit_aer_repo} || {
                echo "Error: Failed to clone qiskit-aer"
                exit 1
            }
        fi

        # Checkout the correct tag (force to handle any dirty state)
        cd ${build_dir}/qiskit-aer
        git fetch --tags
        git checkout --force ${qiskit_aer_tag} || {
            echo "Error: Failed to checkout qiskit-aer tag ${qiskit_aer_tag}"
            exit 1
        }
        git clean -fdx

        # ====================================================================
        # Set up build environment
        # ====================================================================
        
        # Force GCC for all builds (avoid Cray wrappers picking up nvc)
        export CC=$(which gcc)
        export CXX=$(which g++)
        export CUDACXX=$(which nvcc)

        # Set CUDA_PATH for CMake (from NVHPC)
        export CUDA_PATH="${NVIDIA_PATH}/cuda"

        # Conan home for build dependencies
        export CONAN_USER_HOME="${build_dir}/conan"
        mkdir -p "${CONAN_USER_HOME}"

        # Create fresh venv for each version to avoid dependency conflicts
        rm -rf ${build_dir}/venv
        python3 -m venv ${build_dir}/venv
        source ${build_dir}/venv/bin/activate

        pip install --upgrade pip
        
        # ====================================================================
        # Install Qiskit from PyPI (pre-built wheels, no Rust needed)
        # ====================================================================
        
        echo "Installing Qiskit ${tool_ver} from PyPI..."
        mkdir -p "${install_dir}"
        pip install --target="${install_dir}" "qiskit==${tool_ver}" || {
            echo "Error: Failed to install qiskit"
            exit 1
        }

        # ====================================================================
        # Build and install Qiskit Aer with CUDA/cuQuantum support
        # ====================================================================
        
        echo "Building Qiskit Aer ${qiskit_aer_ver} with CUDA and cuQuantum..."
        cd ${build_dir}/qiskit-aer || exit 1
        
        # Clean any previous build artifacts
        rm -rf build dist *.egg-info _skbuild

        pip install -r requirements-dev.txt
        # Build tools not available as modules
        pip install "scikit-build>=0.11.0"
        pip install conan==1.65.0
        pip install pybind11==2.13.4
        pip install cmake ninja
        # numpy, scipy, cython, mpi4py, setuptools loaded as modules

        # Enable GPU-aware MPI for Cray MPICH
        export MPICH_GPU_SUPPORT_ENABLED=1

        # Link against GTL library for GPU-aware MPI on Cray systems (assume present)
        GTL_LIB_PATH="${GTL_LIB_PATH:-${CRAY_MPICH_DIR}/gtl/lib}"
        GTL_LIB="${GTL_LIB_PATH}/libmpi_gtl_cuda.so"
        GTL_LINKER_FLAGS="-L${GTL_LIB_PATH} -lmpi_gtl_cuda -Wl,-rpath,${GTL_LIB_PATH}"
        echo "Assuming GTL library at ${GTL_LIB}"
        if [[ ! -f "${GTL_LIB}" ]]; then
            echo "ERROR: Expected GTL library not found at ${GTL_LIB}"
            echo "Set CRAY_MPICH_DIR or update GTL_LIB_PATH in this script."
            exit 1
        fi
        export LD_LIBRARY_PATH="${GTL_LIB_PATH}:${LD_LIBRARY_PATH}"

        # CUDA architecture (90 = H100/GH200)
        # Use CMAKE_CUDA_ARCHITECTURES (modern CMake) instead of AER_CUDA_ARCH
        # to bypass deprecated cuda_select_nvcc_arch_flags which doesn't know sm_90
        CUDA_ARCH=${CUDA_ARCH:-90}
        echo "Using CUDA architecture: ${CUDA_ARCH}"
        export CUDAARCHS="${CUDA_ARCH}"

        # Build CMake flags array
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

        # Build wheel
        python ./setup.py bdist_wheel -vvv -- "${CMAKE_ARGS[@]}" --

        # Verify GTL library is linked (if we expected it)
        if [[ -n "${GTL_LINKER_FLAGS}" ]]; then
            echo "Verifying GTL library linkage..."
            CONTROLLER_SO=$(find _skbuild -name "controller_wrappers*.so" 2>/dev/null | head -1)
            if [[ -n "${CONTROLLER_SO}" ]]; then
                if ldd "${CONTROLLER_SO}" | grep -q "libmpi_gtl_cuda"; then
                    echo "SUCCESS: GTL library (libmpi_gtl_cuda.so) is linked"
                else
                    echo "ERROR: GTL library is NOT linked to ${CONTROLLER_SO}"
                    echo "Linked MPI libraries:"
                    ldd "${CONTROLLER_SO}" | grep -E "mpi|gtl"
                    exit 1
                fi
            else
                echo "WARNING: Could not find controller_wrappers.so to verify linkage"
            fi
        fi

        pip install --target="${install_dir}" dist/qiskit_aer*.whl || {
            echo "Error: Failed to install qiskit-aer"
            exit 1
        }

        # ====================================================================
        # Cleanup build environment for this version
        # ====================================================================
        
        rm -rf "${CONAN_USER_HOME}"
        deactivate
    fi

    # Create module for this version
    finalize_install
    
    echo "${tool_name}/${tool_ver} installation complete!"
done

# Final cleanup (only if we actually installed software and build_dir is set)
if should_install_software && [[ -n "${build_dir}" ]]; then
    cleanup_build
fi

echo ""
echo "========================================================================"
echo "All Qiskit versions installed successfully!"
echo "========================================================================"
