#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-cuquantum-setonix-q.sh
. $script_dir/utils.sh

# Usage
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [--module-only]"
    echo "  --module-only  Skip software installation, only create/update module file"
    exit 0
fi

# install software (skip if --module-only)
if [[ "$1" != "--module-only" ]]; then 
    echo "Installing ${tool_name}/${tool_ver}"
    set_dependencies

    # Create build directory
    build_dir="$MYSCRATCH/${tool_name}-build"
    mkdir -p ${build_dir}
    cd ${build_dir}

    # Download if not present
    if [[ ! -f "${cuquantum_archive}.tar.xz" ]]; then
        echo "Downloading cuQuantum ${tool_ver}..."
        wget -q "${cuquantum_url}"
    fi

    # Extract
    echo "Extracting..."
    tar -xf "${cuquantum_archive}.tar.xz"

    # Build MPI distributed interface if MPI is available
    if [[ -n "${MPI_HOME}" ]] || command -v mpicc &>/dev/null; then
        echo "Building MPI distributed interface..."
        cd "${cuquantum_archive}/distributed_interfaces"
        
        MPI_INCLUDE="${MPI_HOME:-/usr}/include"
        MPI_LIB="${MPI_HOME:-/usr}/lib"
        CUDA_INCLUDE="${CUDA_HOME:-${NVHPC_ROOT}/cuda}/include"
        
        gcc -shared -std=c99 -fPIC \
            -I"${CUDA_INCLUDE}" -I../include -I"${MPI_INCLUDE}" \
            cutensornet_distributed_interface_mpi.c \
            -L"${MPI_LIB}" -lmpi \
            -o libcutensornet_distributed_interface_mpi.so || \
            echo "Warning: Failed to build MPI interface (non-fatal)"
        
        cd ${build_dir}
    fi

    # Install to destination
    echo "Installing to ${install_dir}..."
    mkdir -p "${install_dir}"
    cp -r ${cuquantum_archive}/* "${install_dir}/"

    # Cleanup
    cd ${script_dir}
    rm -rf ${build_dir}

    echo "cuQuantum installed to ${install_dir}"
fi

# install module (using cuquantum-specific template)
install_module ${install_dir} ${tool_name} ${tool_ver} "${brief}" "${descrip}" "cuquantum-sample.lua"

echo "cuQuantum ${tool_ver} installation complete!"
