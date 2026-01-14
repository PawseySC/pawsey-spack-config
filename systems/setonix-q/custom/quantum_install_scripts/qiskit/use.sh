#!/bin/bash

tool_name="qiskit"

# ============================================================================
# Version configuration
# Both Qiskit 1.x and 2.x are installed by default
# ============================================================================

# Versions to install: "major_version:qiskit_version:aer_version"
QISKIT_VERSIONS=(
    "1:1.4.5:0.17.1"
    "2:2.3.0:0.17.2"
)

nvhpc_ver="${nvidia_version:-24.11}"
gcc_ver="${gcc_version:-12.3.0}"
gcc_module_ver="${gcc_ver%.*}"
cutensor_ver="2.4.1"
cuquantum_ver="25.11.1"
python_ver="3.11.6"

export MODULE_DIR=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

export dependencies=(
cuquantum/${cuquantum_ver} \
python/${python_ver} \
py-numpy/2.1.2 \
py-scipy/1.13.0 \
py-cython/3.0.11 \
py-mpi4py/3.1.5-py3.11.6 \
py-setuptools/70.1.0-py3.11.6 \
)

# Helper function to set version-specific variables
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

# Only qiskit-aer is built from source (for CUDA/cuQuantum support)
# Qiskit itself is installed from PyPI as pre-built wheels
qiskit_aer_repo="https://github.com/Qiskit/qiskit-aer.git"
