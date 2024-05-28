#!/bin/bash

# for cuda-q need cutensor llvm cuquantum

# this will install cuda-q for c++
cudaqurl=https://github.com/NVIDIA/cuda-quantum/releases/download/0.7.1/install_cuda_quantum.aarch64
wget ${cudaqurl}
chmod +x install_cuda_quantum.aarch64
#./install_cuda_quantum.$(uname -m) --accept --target ${PREFIX}/cudaq

# install for python
condaurl=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
fname=Miniconda3-latest-arm.sh
wget -O ${fname} ${condaurl} 
chmod +x ${fname}
./ ${fname} -b -p ${PREFIX}/miniconda3/ -s 
eval "$(${PREFIX}/miniconda3/bin/conda shell.bash hook)"
conda create -y -n cuda-quantum python=3.11 pip
conda install -y -n cuda-quantum -c "nvidia/label/cuda-12.3.0" cuda
conda install -y -n cuda-quantum -c conda-forge mpi4py openmpi cxx-compiler
conda env config vars set -n cuda-quantum LD_LIBRARY_PATH="$CONDA_PREFIX/envs/cuda-quantum/lib:$LD_LIBRARY_PATH"
conda env config vars set -n cuda-quantum MPI_PATH=$CONDA_PREFIX/envs/cuda-quantum
conda run -n cuda-quantum pip install cuda-quantum
conda activate cuda-quantum
source $CONDA_PREFIX/lib/python3.11/site-packages/distributed_interfaces/activate_custom_mpi.sh
