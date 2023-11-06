#!/bin/bash -l
#SBATCH --job-name=install-qiskit-source-rocm-setonix
#SBATCH --account=pawsey0001-gpu
#SBATCH --partition=gpu-dev
#SBATCH --exclusive
#SBATCH --ntasks=1
#SBATCH --threads-per-core=1
#SBATCH --gpus-per-node=8
#SBATCH --time=00:30:00
#SBATCH --output=out-%x

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-qiskit-source-rocm-setonix.sh

# install
if [ -z $1 ]; then 
    echo "Building ${tool_name}/${tool_ver}"
    git clone https://github.com/Qiskit/qiskit-aer $source_dir
    cd $source_dir
    git checkout $tool_ver
    pip install --prefix=$install_dir -r requirements-dev.txt
    pip install --prefix=$install_dir pybind11[global]

    python ./setup.py bdist_wheel -- \
      -DCMAKE_CXX_COMPILER=hipcc \
      -DCMAKE_BUILD_TYPE=Release \
      -DAER_MPI=True \
      -DAER_THRUST_BACKEND=ROCM \
      -DAER_ROCM_ARCH=gfx90a \
      -DAER_DISABLE_GDR=False \
      --

    pip install --prefix=$install_dir dist/qiskit_aer*.whl
    cd -
    rm -rf ${source_dir}
fi

# install module 
${script_dir}/install-module.sh ${install_dir} \
${tool_name} ${tool_ver} \
"${brief}" "${descrip}"
