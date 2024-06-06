#!/bin/bash

# essential for reproducibility of installation
tool_name="qiskit-amd-gfx90a"
# ROCm support is super new, requires `main` branch future to version 0.12.2
tool_ver="39487dbf8cfe002dbf50cbadd923609c933a4a30"
# now should be in new released 0.13.0
tool_ver="0.13.0"

# description
brief="Qiskit is open-source software for working with quantum computers at the level of circuits, pulses, and algorithms."
descrip="Qiskit is open-source software for working with quantum computers at the level of circuits, pulses, and algorithms. \
The central goal of Qiskit is to build a software stack \
that makes it easy for anyone to use quantum computers, \
regardless of their skill level or area of interest; \
Qiskit allows one to easily design experiments and applications \
and run them on real quantum computers or classical simulators. \
Qiskit is already in use around the world by beginners, hobbyists, \
educators, researchers, and commercial companies. \
Qiskit-AER is a high performance simulator for quantum circuits that includes noise models.\
This is the GPU-enabled version."

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
rocm_ver="5.2.3"

# load modules
export dependencies=(\
cmake/$cmake_ver \
openblas/$blas_ver \
python/$py_ver \
py-pip/$pip_ver \
py-setuptools/$st_ver \
py-numpy/$numpy_ver \
py-scipy/$scipy_ver \
py-scikit-learn/$scikit_ver \
py-cython/$cython_ver \
py-h5py/$h5py_ver \
py-mpi4py/$mpi4py_ver \
rocm/$rocm_ver \
craype-accel-amd-gfx90a \
)

export MODULE_DIR=/software/setonix/2023.08/custom/modules/zen3/gcc/12.2.0/custom
export MODULE_DIR_CCE=/software/setonix/2023.08/custom/modules/zen3/cce/15.0.1/custom
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
