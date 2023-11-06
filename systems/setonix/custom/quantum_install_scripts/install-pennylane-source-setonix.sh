#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-pennylane-source-setonix.sh

# install from source

# if no argument is passed then assuming a build is required
if [ -z $1 ]; then 
    echo "Building ${tool_name}/${tool_ver}"
    # install from source
    # note that this repo is deprecated and now should use pennylane-lightning
    # but I cannot get that version to compile
    cd ${base_dir}
    git clone https://github.com/PennyLaneAI/pennylane $source_dir
    cd $source_dir
    git fetch --tags 
    git checkout v$tool_ver

    CMAKE_ARGS="-DCMAKE_CXX_COMPILER=CC \
        -DCMAKE_BUILD_TYPE=Release"
    cmake -B build . ${CMAKE_ARGS}
    cmake --build build
    pip install --prefix=$install_dir .

    cd -
    rm -rf ${source_dir}
fi

# install module 
${script_dir}/install-module.sh ${install_dir} \
${tool_name} ${tool_ver} \
"${brief}" "${descrip}"