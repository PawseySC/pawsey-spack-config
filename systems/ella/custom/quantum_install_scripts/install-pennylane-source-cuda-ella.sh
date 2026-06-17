#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-pennylane-source-cuda-ella.sh
. $script_dir/utils.sh


if [ -z $1 ]; then 
    echo "Building ${tool_name}/${tool_ver}"
    set_dependencies
    # install from source
    git clone https://github.com/PennyLaneAI/pennylane-lightning-kokkos $source_dir
    cd $source_dir
    git fetch --tags 
    git checkout v$tool_ver

    cmake -B build . \
      -DCMAKE_CXX_COMPILER=hipcc \
      -DCMAKE_CXX_FLAGS=--gcc-toolchain=$(dirname $(which g++))/../snos \
      -DPYTHON_EXECUTABLE=$(which python) \
      -DCMAKE_BUILD_TYPE=Release \
      -DKokkos_ENABLE_HIP=OFF \
      -DKokkos_ENABLE_CUDA=ON \
      -DKokkos_ARCH_VEGA90A=OFF \
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
    # currently commenting out and testing 
    # filename=$( basename $( ls $lib_dir/pennylane_lightning_kokkos/lightning_kokkos_qubit_ops.cpython* ) )
    # cp -p build/lightning_kokkos_qubit_ops.cpython* $lib_dir/pennylane_lightning_kokkos/$filename

    cd ${script_dir}
    rm -rf ${source_dir}
fi

# install module 
install_module ${install_dir} \
${tool_name} ${tool_ver} \
"${brief}" "${descrip}"
