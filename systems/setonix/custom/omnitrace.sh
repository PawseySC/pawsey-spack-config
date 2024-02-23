#!/bin/bash
module load rocm/5.2.3
module load craype-accel-amd-gfx90a 
module load PrgEnv-gnu/8.4.0
module load gcc/11.2.0
module load python/3.10.10
module load cmake/3.24.3
module load libtool/2.4.7
git clone https://github.com/AMDResearch/omnitrace.git omnitrace-source
export INSTALL_DIR=/software/setonix/2023.08/custom/software/linux-sles15-zen3/gcc-12.2.0/omnitrace/1.10.2
export MODULE_DIR=/software/setonix/2023.08/custom/modules/zen3/gcc/12.2.0/custom
export MODULE_DIR_CCE=/software/setonix/2023.08/custom/modules/zen3/cce/16.0.1/custom
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
    -D DYNINST_BUILD_ELFUTILS=ON            \
    -D DYNINST_BUILD_LIBIBERTY=ON           \
    omnitrace-source
cmake --build omnitrace-build -v --target all --parallel 64
cmake --build omnitrace-build --target install

cp -r ${INSTALL_DIR}/share/modulefiles/omnitrace/ ${MODULE_DIR}/.
cd ${MODULE_DIR}/omnitrace
sed -i '/set ROOT/c\set ROOT  /software/setonix/2023.08/custom/software/linux-sles15-zen3/gcc-12.2.0/omnitrace/1.10.2' 1.10.2
cp -r ${MODULE_DIR}/omnitrace ${MODULE_DIR_CCE}/.
