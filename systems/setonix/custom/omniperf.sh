#!/bin/bash
export INSTALL_DIR=${INSTALL_PREFIX}/custom/software/linux-sles15-zen3/gcc-12.2.0/omniperf/1.0.10
export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/zen3/gcc/12.2.0/custom
export MODULE_DIR_CCE=${INSTALL_PREFIX}/custom/modules/zen3/cce/16.0.1/custom
mkdir -p ${MODULE_DIR_CCE}
module load python/3.11.6 
module load py-pip/23.1.2-py3.11.6 
module --ignore-cache load cmake/3.27.7
wget https://github.com/AMDResearch/omniperf/releases/download/v1.0.10/omniperf-v1.0.10.tar.gz
tar -xf omniperf-v1.0.10.tar.gz
cd omniperf-1.0.10/
python3 -m pip install -t ${INSTALL_DIR}/python-libs -r requirements.txt
mkdir build
cd build/
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DPYTHON_DEPS=${INSTALL_DIR}/python-libs -DMOD_INSTALL_PATH=${MODULE_DIR} ..
make install
cd ../..
rm omniperf-v1.0.10.tar.gz
rm -rf omniperf-1.0.10
cd ${MODULE_DIR}/omniperf
sed -i -e '$adepends_on("python/3.11.6")' 1.0.10.lua
cp -r ${MODULE_DIR}/omniperf ${MODULE_DIR_CCE}/.
