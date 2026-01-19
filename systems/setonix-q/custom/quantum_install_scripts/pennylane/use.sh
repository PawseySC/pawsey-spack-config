#!/bin/bash

tool_name="py-pennylane"
tool_ver="0.44.0"

# PennyLane-Lightning GPU version (should match pennylane version)
lightning_ver="${tool_ver}"

brief="PennyLane quantum computing framework with GPU acceleration"
descrip="PennyLane is a cross-platform Python library for quantum computing, \
quantum machine learning, and quantum chemistry. This installation includes \
PennyLane ${tool_ver} with Lightning-GPU built from source against the system \
cuQuantum installation, with MPI support for distributed state-vector simulation \
across multiple GPUs."

nvhpc_ver="${nvidia_version}"
gcc_ver="${gcc_version}"
gcc_module_ver="${gcc_ver%.*}"
build_compiler="gcc@${gcc_ver}"
cuquantum_ver="25.11.1"
cutensor_ver="2.4.1"
python_ver="3.11.6"
cray_mpich_ver="8.1.33"

export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
cuquantum/${cuquantum_ver} \
cutensor/${cutensor_ver} \
python/${python_ver} \
py-numpy/2.1.2 \
py-mpi4py/4.0.1-py3.11.6 \
)

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${tool_ver}/lib/python${python_ver%.*}/site-packages"

cray_mpich_dir_gnu="/opt/cray/pe/mpich/${cray_mpich_ver}/ofi/gnu/${gcc_module_ver}"
export CRAY_MPICH_DIR="${CRAY_MPICH_DIR:-${cray_mpich_dir_gnu}}"
export GTL_LIB_PATH="${GTL_LIB_PATH:-${cray_mpich_dir_gnu}/lib}"
