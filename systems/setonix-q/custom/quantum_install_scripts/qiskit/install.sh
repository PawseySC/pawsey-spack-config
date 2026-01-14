#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

parse_args "$@"

# ============================================================================
# Install each Qiskit version
# ============================================================================

for version_string in "${QISKIT_VERSIONS[@]}"; do
    set_qiskit_version "${version_string}"
    
    echo ""
    echo "========================================================================"
    echo "Installing ${tool_name}/${tool_ver} with qiskit-aer/${qiskit_aer_ver}"
    echo "========================================================================"

    if should_install_software; then
        set_dependencies
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
        pip install --force-reinstall "scikit-build>=0.11.0"
        pip install --force-reinstall conan==1.65.0
        pip install --force-reinstall pybind11==2.13.4
        pip install cmake ninja
        # numpy, scipy, cython, mpi4py, setuptools loaded as modules

        # Enable GPU-aware MPI for Cray MPICH
        export MPICH_GPU_SUPPORT_ENABLED=1

        python ./setup.py bdist_wheel -vvv -- \
            -DAER_THRUST_BACKEND=CUDA \
            -DCUQUANTUM_ROOT="${CUQUANTUM_ROOT}" \
            -DCUTENSOR_ROOT="${CUTENSOR_ROOT}" \
            -DAER_MPI=True \
            -DAER_ENABLE_CUQUANTUM=true \
            --

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
