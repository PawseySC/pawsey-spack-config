#!/bin/bash 
# Copyright: Pawsey Supercomputing Research Centre
# Author: Cristian Di Pietrantonio

# NOTE!! Must be run on a compute node with at least one GPU for it to detect the architecture.
AMBER_SRC_DIR=$MYSCRATCH/amber_src
BUILD_DIR=$MYSCRATCH/amber_build_automated
INSTALL_DIR=$MYSCRATCH/amber_install_automated
amber_tools_src=$AMBER_SRC_DIR/AmberTools22jlmrcc.tar.bz2
amber_src=$AMBER_SRC_DIR/Amber22.tar.bz2
rocm_patch=$AMBER_SRC_DIR/amber_amd.3jan23.tar.bz2

module load craype-accel-amd-gfx90a
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# extract source code
tar xf $amber_tools_src
tar xf $amber_src
cd amber22_src
tar xf $rocm_patch

# Fix No. 1 - Force the use of external boost
sed -i -e '204d' -e '203 aset(SUSPICIOUS_3RDPARTY_TOOLS mkl)' CMakeLists.txt 
# Fix No. 2 - Removes dependency on libopen-pal, an OpenMPI related library. We do not have it on Cray Shasta,
# and I am not sure why it is needed.
sed -i '80d' src/pmemd/src/cuda/CMakeLists.txt
# Fix No. 3 - Seems like CMake is not able to properly configure/find Cray MPICH. Hence I have to set the value
# for MPI_CXX_LIBRARIES and MPI_Fortran_LIBRARIES manually.
sed -i -e '8 aset(MPI_CXX_LIBRARIES "${MPI_C_LIBRARIES}")' \
    -e '9 aset(MPI_Fortran_LIBRARIES "libmpifort.so")' cmake/MPIConfig.cmake 
# Fix No. 4 - Add gfx90a support
sed -i -e '894 s/ CACHE STRING/;gfx90a:xnack- CACHE STRING/g'\
       -e '896 s/ CACHE STRING/;gfx90a CACHE STRING/g' cmake/FindHipCUDA.cmake

# Load dependencies
module load py-numpy/1.20.3 python/3.9.15 boost/1.80.0-c++14-python parallel-netcdf/1.12.2  openblas/0.3.15 cmake/3.21.4 fftw/3.3.9  rocm/5.0.2  netcdf-c/4.8.1 netcdf-fortran/4.5.3  

PREFIX_DIR=$INSTALL_DIR

cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D COMPILER=AUTO \
    -D CMAKE_C_COMPILER=gcc \
    -D CMAKE_CXX_COMPILER=g++ \
    -D CMAKE_Fortran_COMPILER=gfortran \
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D CMAKE_C_FLAGS="-O3 " \
    -D CMAKE_Fortran_FLAGS="-O3"  \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D BUILD_PYTHON=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D HIP=ON \
    -D CUDA=OFF\
    -D BUILD_QUICK=OFF\
    -D GTI=TRUE \
    -D VKFFT=ON \
    -D HIP_RDC=ON \
    -D HIP_TOOLKIT_ROOT_DIR=$ROCM_PATH \
    -D HIPCUDA_EMULATE_VERSION="10.1" \
    -D BUILD_HOST_TOOLS=ON \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR/tools \
    -S . \
    -B build/tools


cmake \
    --build build/tools \
    --target install \
    -j16

cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D COMPILER=CRAY\
    -DFORCE_EXTERNAL_LIBS=netcdf\
    -D CMAKE_C_COMPILER=cc\
    -D CMAKE_CXX_COMPILER=CC\
    -D CMAKE_Fortran_COMPILER=ftn\
    -D MPI_C_COMPILER=cc\
    -D MPI_CXX_COMPILER=CC\
    -D MPI_Fortran_COMPILER=ftn\
    -D NetCDF_INCLUDES_F77=${PAWSEY_NETCDF_FORTRAN_HOME}/include\
    -D NetCDF_INCLUDES_F90=${PAWSEY_NETCDF_FORTRAN_HOME}/include\
    -D MPI_HOME=${MPICH_DIR}\
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpi\
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D HIP_ARCHITECTURES=gfx908\
    -D CMAKE_C_FLAGS="-O3 " \
    -D CMAKE_Fortran_FLAGS="-O3" \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D BUILD_PYTHON=OFF \
    -D CUDA=OFF\
    -D BUILD_QUICK=OFF\
    -D MPI=ON\
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D HIP=ON \
    -D GTI=TRUE \
    -D HIP_RDC=ON \
    -D VKFFT=ON \
    -D HIP_TOOLKIT_ROOT_DIR=$ROCM_PATH \
    -D HIPCUDA_EMULATE_VERSION="10.1" \
    -D BUILD_HOST_TOOLS=OFF \
    -D USE_HOST_TOOLS=ON \
    -D HOST_TOOLS_DIR=$PREFIX_DIR/tools \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR \
    -S . \
    -B build/amber \

cmake \
    --build build/amber \
    --target xblas_build \

cmake \
    --build build/amber \
    --target install \
    -j16
