#!/bin/bash

export base_dir=/scratch/pawsey0001/pelahi/quantum-tests
script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-qiskit-source-mpi-omp-setonix.sh

# install
git clone https://github.com/Qiskit/qiskit-aer $source_dir/qiskit-aer
cd $source_dir/qiskit-aer
git checkout $aer_ver
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
