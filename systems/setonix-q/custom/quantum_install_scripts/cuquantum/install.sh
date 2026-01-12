#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

# Parse arguments
parse_args "$@"

# Install software (skip if --module-only)
if should_install_software; then
    echo "Installing ${tool_name}/${tool_ver}"
    set_dependencies
    setup_build_dir
    download_archive "${cuquantum_archive}.tar.xz" "${cuquantum_url}"
    extract_archive "${cuquantum_archive}.tar.xz"

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

    install_files "${cuquantum_archive}"
    cleanup_build
fi

# Install module
finalize_install
