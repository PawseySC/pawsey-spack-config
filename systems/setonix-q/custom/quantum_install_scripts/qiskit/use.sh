#!/bin/bash

tool_name="py-qiskit"

# Versions to install: "major_version:qiskit_version:aer_version"
QISKIT_VERSIONS=(
    "1:1.4.5:0.17.1"
    "2:2.3.0:0.17.2"
)

nvhpc_ver="${nvidia_version}"
gcc_ver="${gcc_version}"
gcc_module_ver="${gcc_ver%.*}"
cutensor_ver="2.4.1"
cuquantum_ver="25.11.1"
python_ver="3.11.6"
cray_mpich_ver="8.1.33"
cray_mpich_dir_gnu="/opt/cray/pe/mpich/${cray_mpich_ver}/ofi/gnu/${gcc_module_ver}"

export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
cutensor/${cutensor_ver} \
cuquantum/${cuquantum_ver} \
python/${python_ver} \
py-numpy/2.1.2 \
py-cython/3.0.11 \
)

export CRAY_MPICH_DIR="${CRAY_MPICH_DIR:-${cray_mpich_dir_gnu}}"
export GTL_LIB_PATH="${GTL_LIB_PATH:-${cray_mpich_dir_gnu}/lib}"

function set_qiskit_version() {
    local version_string=$1
    IFS=':' read -r major_ver tool_ver qiskit_aer_ver <<< "${version_string}"
    
    export tool_ver
    export qiskit_aer_ver
    export qiskit_tag="${tool_ver}"
    export qiskit_aer_tag="${qiskit_aer_ver}"
    export install_dir="${base_dir}/${tool_name}/${tool_ver}"
    
    case "${major_ver}" in
        1)
            export brief="Qiskit 1.x quantum computing SDK with Aer high-performance simulator"
            export descrip="Qiskit is an open-source SDK for working with quantum computers. \
This installation includes Qiskit ${tool_ver} and Qiskit Aer ${qiskit_aer_ver} with CUDA GPU \
acceleration and NVIDIA cuQuantum integration. Qiskit 1.x is the legacy version \
maintained for compatibility with existing workflows."
            ;;
        2)
            export brief="Qiskit 2.x quantum computing SDK with Aer high-performance simulator"
            export descrip="Qiskit is an open-source SDK for working with quantum computers. \
This installation includes Qiskit ${tool_ver} and Qiskit Aer ${qiskit_aer_ver} with CUDA GPU \
acceleration and NVIDIA cuQuantum integration. Qiskit 2.x is the latest major version \
with improved performance and new features."
            ;;
    esac
}

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

qiskit_aer_repo="https://github.com/Qiskit/qiskit-aer.git"
