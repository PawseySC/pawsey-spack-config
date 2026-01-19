#!/bin/bash

tool_name="py-mpi4py"
tool_ver="4.0.1"

brief="MPI for Python with GPU-aware CUDA support"
descrip="MPI for Python (mpi4py) provides Python bindings for the Message Passing \
Interface (MPI) standard. This installation is built with GPU-aware MPI support, \
linking against the Cray MPICH GTL library for efficient GPU-to-GPU communication \
across nodes."

# Use versions from settings.sh
nvhpc_ver="${nvidia_version}"
gcc_ver="${gcc_version}"
gcc_module_ver="${gcc_ver%.*}"
python_ver="3.11.6"
cray_mpich_ver="8.1.33"
spack_ver="${spack_version}"

cray_mpich_dir_gnu="/opt/cray/pe/mpich/${cray_mpich_ver}/ofi/gnu/${gcc_module_ver}"
export GTL_LIB_PATH="${cray_mpich_dir_gnu}/lib"

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
