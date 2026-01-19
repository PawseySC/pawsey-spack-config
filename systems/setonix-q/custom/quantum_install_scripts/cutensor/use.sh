#!/bin/bash

# essential for reproducibility of installation
tool_name="cutensor"
tool_ver="2.4.1"
archive_ver="2.4.1.4"
cuda_ver="cuda12"

# description
brief="NVIDIA cuTENSOR - GPU-accelerated tensor linear algebra library"
descrip="NVIDIA cuTENSOR is a GPU-accelerated tensor linear algebra library providing \
tensor contraction, reduction, and elementwise operations. It is a key dependency for \
cuQuantum's cuTensorNet library and provides optimized performance for tensor computations \
on NVIDIA GPUs."

# Architecture (sbsa for ARM/Grace, x86_64 for AMD/Intel)
if [[ "$(uname -m)" == "aarch64" ]]; then
    cutensor_arch="sbsa"
else
    cutensor_arch="x86_64"
fi

# Use versions from settings.sh (must be sourced before running)
nvhpc_ver="${nvidia_version}"
gcc_ver="${gcc_version}"
# Extract major.minor from gcc version (e.g., 12.3.0 -> 12.3) for module loading
gcc_module_ver="${gcc_ver%.*}"

# load modules (explicit toolchain + CUDA)
export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
)

# Paths derived from settings.sh variables
export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

# internal variables - do not edit
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${tool_ver}"

# cuTensor specific
cutensor_archive="libcutensor-linux-${cutensor_arch}-${archive_ver}_${cuda_ver}-archive"
cutensor_url="https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/linux-${cutensor_arch}/${cutensor_archive}.tar.xz"
