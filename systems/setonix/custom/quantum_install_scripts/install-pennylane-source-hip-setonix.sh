#!/bin/bash -l
#SBATCH --job-name=install-pennylane-source-hip-setonix
#SBATCH --account=pawsey0001-gpu
#SBATCH --partition=gpu-dev
#SBATCH --exclusive
#SBATCH --ntasks=1
#SBATCH --threads-per-core=1
#SBATCH --gpus-per-node=8
#SBATCH --time=00:30:00
#SBATCH --output=out-%x

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-pennylane-source-hip-setonix.sh
export base_dir=/scratch/pawsey0001/pelahi/quantum-tests

# install from source
git clone https://github.com/PennyLaneAI/pennylane-lightning-kokkos $source_dir/pennylane-lightning-kokkos
cd $source_dir/pennylane-lightning-kokkos
git fetch --tags 
git checkout v$pl_ver

#CMAKE_ARGS="-DCMAKE_CXX_COMPILER=hipcc \
#  -DCMAKE_BUILD_TYPE=Release \
#  -DKokkos_ENABLE_HIP=ON \
#  -DKokkos_ARCH_VEGA90A=ON \
#  -DPLKOKKOS_ENABLE_NATIVE=ON" \
#  pip install --prefix=$install_dir .

cmake -B build . \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_CXX_FLAGS=--gcc-toolchain=$(dirname $(which g++))/../snos \
  -DPYTHON_EXECUTABLE=$(which python) \
  -DCMAKE_BUILD_TYPE=Release \
  -DKokkos_ENABLE_HIP=ON \
  -DKokkos_ARCH_VEGA90A=ON \
  -DPLKOKKOS_ENABLE_NATIVE=ON
#  -DCMAKE_VERBOSE_MAKEFILE=ON \
#  -DPLKOKKOS_ENABLE_WARNINGS=ON \

# Edric's workaround for __noinline__ build issue
# Also requires --gcc-toolchain above
files=$(grep -rl "#include <memory>" build)
for file in $files; do
  echo "Patching $file"
  sed -i 's/#include <memory>/#ifdef __noinline__\
      #define GCC12_RESTORE_NOINLINE\
      #undef __noinline__\
    #endif\
    #include <memory>\
    #ifdef GCC12_RESTORE_NOINLINE\
      #undef GCC12_RESTORE_NOINLINE\
      #define __noinline__ _attribute((noinline))\
    #endif/g' $file
done

cmake --build build
pip install --prefix=$install_dir .

# bugfix - why on earth?
filename=$( basename $( ls $lib_dir/pennylane_lightning_kokkos/lightning_kokkos_qubit_ops.cpython* ) )
cp -p build/lightning_kokkos_qubit_ops.cpython* $lib_dir/pennylane_lightning_kokkos/$filename

cd -
