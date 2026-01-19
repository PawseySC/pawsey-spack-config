#!/bin/bash

tool_name="py-pennylane-qiskit"

# Version configuration - these are the ground truth for this installation
plugin_ver="0.44.0"
qiskit_ver="2.3.0"
pennylane_ver="0.44.0"

tool_ver="${plugin_ver}"

brief="PennyLane-Qiskit plugin ${plugin_ver} for Qiskit ${qiskit_ver}"
descrip="Registers Qiskit devices in PennyLane, enabling qiskit.aer and hardware backends."

nvhpc_ver="${nvidia_version}"
python_ver="3.11.6"

export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
py-qiskit-nompi/${qiskit_ver} \
py-pennylane/${pennylane_ver} \
python/${python_ver} \
)

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${tool_ver}/lib/python${python_ver%.*}/site-packages"
