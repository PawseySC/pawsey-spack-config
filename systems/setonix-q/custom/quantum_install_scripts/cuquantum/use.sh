#!/bin/bash

# essential for reproducibility of installation
tool_name="cuquantum"
tool_ver="25.11.1"
archive_ver="25.11.1.11"
cuda_ver="cuda12"

# description
brief="NVIDIA cuQuantum SDK - GPU-accelerated quantum computing libraries"
descrip="NVIDIA cuQuantum SDK provides optimized libraries for quantum circuit simulation. \
It includes cuStateVec for state vector simulation on GPU and cuTensorNet for tensor network \
contraction on GPU. cuQuantum enables high-performance quantum computing research and development \
by leveraging NVIDIA GPU acceleration."

# Architecture (sbsa for ARM/Grace, x86_64 for AMD/Intel)
if [[ "$(uname -m)" == "aarch64" ]]; then
    cuquantum_arch="sbsa"
else
    cuquantum_arch="x86_64"
fi

# Use versions from settings.sh (must be sourced before running)
nvhpc_ver="${nvidia_version}"
gcc_ver="${gcc_version}"
# Extract major.minor from gcc version (e.g., 12.3.0 -> 12.3) for module loading
gcc_module_ver="${gcc_ver%.*}"
build_compiler="nvhpc@${nvhpc_ver}"
cutensor_ver="2.4.1"

# load modules (explicit toolchain + CUDA + cutensor)
export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
cutensor/${cutensor_ver} \
)

# Paths derived from settings.sh variables
export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

# internal variables - do not edit
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${tool_ver}"

# cuQuantum specific
cuquantum_archive="cuquantum-linux-${cuquantum_arch}-${archive_ver}_${cuda_ver}-archive"
cuquantum_url="https://developer.download.nvidia.com/compute/cuquantum/redist/cuquantum/linux-${cuquantum_arch}/${cuquantum_archive}.tar.xz"
