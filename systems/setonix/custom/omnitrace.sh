#!/bin/bash
export INSTALL_DIR=${INSTALL_PREFIX}/custom/software/linux-sles15-zen3/gcc-12.2.0/omnitrace/1.11.2
export MODULE_DIR=${INSTALL_PREFIX}/custom/modules/zen3/gcc/12.2.0/custom
#export MODULE_DIR_CCE=${INSTALL_PREFIX}/custom/modules/zen3/cce/15.0.1/custom
module load rocm/5.2.3
module load craype-accel-amd-gfx90a 
module load PrgEnv-gnu/8.3.3
module load gcc/11.2.0
module load python/3.11.6
module load cmake/3.27.7
module load libtool/2.4.7
git clone --no-checkout https://github.com/AMDResearch/omnitrace.git omnitrace-source
cd omnitrace-source
git checkout tags/v1.11.2
cd ..
#cp toolchain.cmake omnitrace-source/.
cmake                                       \
    -B omnitrace-build                      \
    -D CMAKE_INSTALL_PREFIX=${INSTALL_DIR}  \
    -D OMNITRACE_USE_HIP=ON                 \
    -D OMNITRACE_USE_ROCM_SMI=ON            \
    -D OMNITRACE_USE_ROCTRACER=ON           \
    -D OMNITRACE_USE_PYTHON=ON              \
    -D OMNITRACE_USE_OMPT=ON                \
    -D OMNITRACE_USE_MPI_HEADERS=ON         \
    -D OMNITRACE_BUILD_PAPI=ON              \
    -D OMNITRACE_BUILD_LIBUNWIND=ON         \
    -D OMNITRACE_BUILD_DYNINST=ON           \
    -D DYNINST_BUILD_TBB=ON                 \
    -D DYNINST_BUILD_BOOST=ON               \
    -D DYNINST_BUILD_ELFUTILS=ON           \
    -D DYNINST_BUILD_LIBIBERTY=ON           \
    omnitrace-source
cmake --build omnitrace-build -v --target all --parallel 64
cmake --build omnitrace-build --target install

cp -r ${INSTALL_DIR}/share/modulefiles/omnitrace/ ${MODULE_DIR}/.
cd ${MODULE_DIR}/omnitrace
sed -i '/set ROOT/c\set ROOT  /software/setonix/2023.08/custom/software/linux-sles15-zen3/gcc-12.2.0/omnitrace/1.11.2' 1.11.2
#cp -r ${MODULE_DIR}/omnitrace ${MODULE_DIR_CCE}/.

#    -D CMAKE_CXX_COMPILER=g++               \
#    -D CMAKE_C_COMPILER=gcc                 \
