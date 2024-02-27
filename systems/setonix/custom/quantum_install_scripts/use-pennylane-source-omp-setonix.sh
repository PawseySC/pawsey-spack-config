#!/bin/bash

# essential for reproducibility of installation
# pennylane versions
tool_name="pennylane-lightning"
tool_ver="0.33.1"

# description
brief="PennyLane Python library for quantum computers."
descrip="PennyLane is a cross-platform Python library for \
differentiable programming of quantum computers. \
Train a quantum computer the same way as a neural network." 

# host versions
py_ver="3.10.10"
pip_ver="23.1.2-py3.10.10"
st_ver="68.0.0-py3.10.10"
# lets try the older version that is compatible with numpy 
st_ver="59.4.0-py3.10.10"
# now some packages
numpy_ver="1.23.4"
scipy_ver="1.8.1"
scikit_ver="1.1.3"
cython_ver="0.29.32"
h5py_ver="3.7.0"
mpi4py_ver="3.1.4-py3.10.10"

cmake_ver="3.24.3"


# load modules
export dependencies=(\
cmake/$cmake_ver \
python/$py_ver \
py-pip/$pip_ver \
py-setuptools/$st_ver \
py-numpy/$numpy_ver \
py-scipy/$scipy_ver \
py-scikit-learn/$scikit_ver \
py-mpi4py/$mpi4py_ver\
)

export MODULE_DIR=/software/setonix/2023.08/custom/modules/zen3/gcc/12.2.0/custom
export MODULE_DIR_CCE=/software/setonix/2023.08/custom/modules/zen3/cce/16.0.1/custom
export base_dir=/software/setonix/2023.08/custom/software/linux-sles15-zen3/gcc-12.2.0/

# internal variables - do not edit
python_ver="$( python3 -V | cut -d ' ' -f 2 | cut -d . -f 1,2 )"
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
install_dir="$base_dir/$tool_name/${tool_ver}"
source_dir="$MYSCRATCH/$tool_name-src/${tool_ver}"
lib_dir="$install_dir/lib/python${python_ver}/site-packages"
bin_dir="$install_dir/bin"

#
export PYTHONPATH="$lib_dir:$PYTHONPATH"
export PATH="$bin_dir:$PATH"
