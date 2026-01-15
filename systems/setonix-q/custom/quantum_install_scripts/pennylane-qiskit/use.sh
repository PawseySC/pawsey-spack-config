#!/bin/bash

tool_name="pennylane-qiskit"
# Plugin version; override with pennylane_qiskit_ver if needed
plugin_ver="${pennylane_qiskit_ver:-0.44.0}"
# Qiskit version this plugin module targets
qiskit_ver="${qiskit_version:-2.3.0}"
# PennyLane version to pair with
pennylane_ver="${pennylane_version:-0.44.0}"

brief="PennyLane-Qiskit plugin ${plugin_ver} for Qiskit ${qiskit_ver}"
descrip="Registers Qiskit devices in PennyLane, enabling qiskit.aer and hardware backends."

nvhpc_ver="${nvidia_version:-24.11}"
python_ver="3.11.6"

export MODULE_DIR=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/modules/neoverse_v2/nvhpc/${nvhpc_ver}/custom
export base_dir=${INSTALL_PREFIX:-/software/setonix-q/2026.01}/custom/software/linux-sles15-neoverse_v2/nvhpc-${nvhpc_ver}

export dependencies=(
PrgEnv-gnu-nvidia \
cudatoolkit-gnu-nvidia \
qiskit/${qiskit_ver} \
pennylane/${pennylane_ver} \
python/${python_ver} \
)

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="${base_dir}/${tool_name}/${qiskit_ver}/lib/python${python_ver%.*}/site-packages"
