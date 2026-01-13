#!/bin/bash

tool_name="qiskit-aer"
tool_ver="0.17.2"

brief="Qiskit Aer - high performance quantum circuit simulator with GPU/cuQuantum support"
descrip="Qiskit Aer is a high performance simulator for quantum circuits written in Qiskit. \
This build includes CUDA GPU acceleration and NVIDIA cuQuantum integration for accelerated \
statevector, density matrix, and tensor network simulations on NVIDIA GPUs."

nvhpc_ver="${nvidia_version:-24.11}"
gcc_ver="${gcc_version:-12.3.0}"
gcc_module_ver="${gcc_ver%.*}"
cutensor_ver="2.4.1"
cuquantum_ver="25.11.1"
python_ver="3.11.6"

export dependencies=(
cuquantum/${cuquantum_ver} \
python/${python_ver} \
py-numpy/2.1.2 \
py-scipy/1.13.0 \
py-cython/3.0.11 \
py-mpi4py/3.1.5-py3.11.6 \
py-setuptools/70.1.0-py3.11.6 \
)

export MODULE_DIR=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${tool_ver}"

qiskit_aer_repo="https://github.com/Qiskit/qiskit-aer.git"
qiskit_aer_tag="${tool_ver}"
