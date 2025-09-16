#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-pennylane-source-omp-setonix-q.sh
. $script_dir/utils.sh

# if no argument is passed then assuming a build is required
if [ -z $1 ]; then 
    echo "Building ${tool_name}/${tool_ver}"
    set_dependencies
    # install from source
    # note that this repo is deprecated and now should use pennylane-lightning
    # but I cannot get that version to compile
    cd ${base_dir}
    git clone https://github.com/PennyLaneAI/pennylane-lightning $source_dir
    cd $source_dir
    git fetch --tags 
    git checkout v$tool_ver

    CMAKE_ARGS="-DCMAKE_CXX_COMPILER=CC \
        -DCMAKE_BUILD_TYPE=Release \
        -DPLKOKKOS_ENABLE_NATIVE=ON \
        -DKokkos_ENABLE_OPENMP=ON \
        -DKokkos_ARCH_ARMV9_GRACE=On
        -DPL_BACKEND=lightning_kokkos"
    cmake -B build . ${CMAKE_ARGS}

    # silly patch to turn off all warnings as errors 
    sed -i "s/target_compile_options(lightning_compile_options INTERFACE $<$<COMPILE_LANGUAGE:CXX>:-Wall;-Wextra;-Werror>)/target_compile_options(lightning_compile_options INTERFACE $<$<COMPILE_LANGUAGE:CXX>:-Wall;-Wextra>)/g" cmake/process_options.cmake

    cmake --build build
    pip install --prefix=$install_dir .

    cd -
    rm -rf ${source_dir}
fi

# install module 
install_module ${install_dir} \
${tool_name} ${tool_ver} \
"${brief}" "${descrip}"