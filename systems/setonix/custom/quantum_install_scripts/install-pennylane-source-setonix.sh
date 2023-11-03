#!/bin/bash

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-pennylane-source-setonix.sh
cd ${base_dir}

# install from source
git clone https://github.com/PennyLaneAI/pennylane $source_dir
cd $source_dir
git fetch --tags 
git checkout v$tool_ver

CMAKE_ARGS="-DCMAKE_CXX_COMPILER=CC \
  -DCMAKE_BUILD_TYPE=Release \
  pip install --prefix=$install_dir .

cd -
rm -rf ${source_dir}
