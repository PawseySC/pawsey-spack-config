#!/bin/bash
module load python/3.10.10 
module load py-pip/23.1.2-py3.10.10
module load cmake/3.21.4
wget https://github.com/AMDResearch/omniperf/releases/download/v1.0.6/omniperf-v1.0.6.tar.gz
tar -xf omniperf-v1.0.6.tar.gz
cd omniperf-1.0.6/
cd src/
sed -i 's/15.3/15.4/g' omniperf
sed -i 's/15.3/15.4/g' common.py
cd ..
export INSTALL_DIR=/software/setonix/2023.08/custom/software/linux-sles15-zen3/gcc-12.2.0/omniperf/1.0.6
export MODULE_DIR=/software/setonix/2023.08/custom/modules/zen3/gcc/12.2.0/custom
python3 -m pip install -t ${INSTALL_DIR}/python-libs -r requirements.txt
mkdir build
cd build/
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/1.0.6 -DPYTHON_DEPS=${INSTALL_DIR}/python-libs -DMOD_INSTALL_PATH=${MODULE_DIR} ..
make install
cd ../..
rm omniperf-v1.0.6.tar.gz
rm -rf omniperf-1.0.6
cd ${MODULE_DIR}/omniperf
sed -i -e '$adepends_on("python/3.10.10")' 1.0.6.lua
