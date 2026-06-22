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
cray_mpich_gnu_abi_ver="12.3"
cuda_ver="${cuda_version}"
python_ver="3.11.6"
cray_mpich_ver="9.1.0"
spack_ver="${spack_version}"
mpi4py_module="${MPI4PY_MODULE:-python-packages/py-mpi4py/${tool_ver}-py${python_ver}}"

cray_mpich_dir_gnu="/opt/cray/pe/mpich/${cray_mpich_ver}/ofi/gnu/${cray_mpich_gnu_abi_ver}"
export GTL_LIB_PATH="${cray_mpich_dir_gnu}/lib"

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
