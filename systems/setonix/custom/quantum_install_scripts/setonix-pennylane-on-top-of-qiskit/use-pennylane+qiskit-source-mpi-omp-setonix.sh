#!/bin/bash

# essential for reproducibility of installation
tool_name="pennylane+qiskit-mpi-omp"
pl_ver="0.32.0"
#qk_ver="0.44.1"
aer_ver="0.12.2"

# host versions
py_ver="3.10.10"
pip_ver="23.1.2-py3.10.10"
st_ver="68.0.0-py3.10.10"
blas_ver="0.3.21"

# load modules
module load python/$py_ver
module load py-pip/$pip_ver
module load py-setuptools/$st_ver
module load openblas/$blas_ver

# internal variables - do not edit
python_ver="$( python3 -V | cut -d ' ' -f 2 | cut -d . -f 1,2 )"
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="$script_dir/$tool_name"
source_dir="${install_dir}-src"
lib_dir="$install_dir/lib/python${python_ver}/site-packages"
bin_dir="$install_dir/bin"
#
export PYTHONPATH="$lib_dir:$PYTHONPATH"
export PATH="$bin_dir:$PATH"
