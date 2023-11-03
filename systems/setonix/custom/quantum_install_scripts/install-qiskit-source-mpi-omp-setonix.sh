#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-qiskit-source-mpi-omp-setonix.sh

# install
git clone https://github.com/Qiskit/qiskit-aer $source_dir
cd $source_dir
git checkout $tool_ver
pip install --prefix=$install_dir -r requirements-dev.txt
pip install --prefix=$install_dir pybind11[global]

python ./setup.py bdist_wheel -- \
  -DCMAKE_CXX_COMPILER=CC \
  -DCMAKE_BUILD_TYPE=Release \
  -DAER_MPI=True \
  -DAER_THRUST_BACKEND=OMP \
  -DAER_DISABLE_GDR=True \
  --

pip install --prefix=$install_dir dist/qiskit_aer*.whl
cd -
rm -rf ${source_dir}
