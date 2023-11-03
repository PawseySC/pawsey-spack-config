#!/bin/bash

# essential for reproducibility of installation
tool_name="qiskit-mpi-omp"
#qk_ver="0.44.1"
aer_ver="0.13.0"

# host versions
py_ver="3.10.10"
pip_ver="23.1.2-py3.10.10"
# lets try the older version that is compatible with numpy
st_ver="59.4.0-py3.10.10"
# now some packages
numpy_ver="1.23.4"
scipy_ver="1.8.1"
scikit_ver="1.1.3"
cython_ver="0.29.32"
h5py_ver="3.7.0"
mpi4py_ver="3.1.4-py3.10.10"

# non python modules
blas_ver="0.3.21"
cmake_ver="3.24.3"

# load modules
module load python/$py_ver
module load py-pip/$pip_ver
module load py-setuptools/$st_ver
module load py-numpy/$numpy_ver
module load py-scipy/$scipy_ver
module load py-mpi4py/$mpi4py_ver
module load py-scikit-learn/$scikit_ver

module load openblas/$blas_ver
module load cmake/$cmake_ver

# internal variables - do not edit
python_ver="$( python3 -V | cut -d ' ' -f 2 | cut -d . -f 1,2 )"
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
base_dir=/scratch/pawsey0001/pelahi/quantum-tests/
install_dir="$base_dir/$tool_name"
source_dir="${install_dir}-src"
lib_dir="$install_dir/lib/python${python_ver}/site-packages"
bin_dir="$install_dir/bin"
#
export PYTHONPATH="$lib_dir:$PYTHONPATH"
export PATH="$bin_dir:$PATH"

