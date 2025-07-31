#!/bin/bash 
# Copyright: Pawsey Supercomputing Research Centre
# Author: Cristian Di Pietrantonio
AMBER_VERSION=24
AMBER_SRC_DIR=/software/setonix/licensed_src/amber
BUILD_DIR=$MYSCRATCH/amber_build_automated
INSTALL_DIR=$MYSCRATCH/amber_install_automated #/software/setonix/2024.05/software/linux-sles15-zen3/gcc-12.2.0/amber-amd-gfx90a/22 
MODULE_DIR=${MYSCRATCH}/modulefiles/amber-amd-gfx90a
amber_tools_src=$AMBER_SRC_DIR/AmberTools24.tar.bz2
amber_src=$AMBER_SRC_DIR/Amber24.tar.bz2

mkdir -p $BUILD_DIR
cd $BUILD_DIR
# extract source code
tar xf $amber_tools_src
tar xf $amber_src
cd amber24_src
# Fix No. 1 - Force the use of external boost
sed -i -e '216d' -e '215 aset(SUSPICIOUS_3RDPARTY_TOOLS mkl)' CMakeLists.txt 
# Fix No. 2 - Removes dependency on libopen-pal, an OpenMPI related library. We do not have it on Cray Shasta,
# and I am not sure why it is needed.
sed -i '84d' src/pmemd/src/cuda/CMakeLists.txt
# Fix missing macro
sed -i -e '49 a#    define cusparseErrorCheck(error) if(error != hipSuccess) {printf("hipsparse error."); exit(1);}' AmberTools/src/pbsa/hip_definitions.h 

# other errors to fix
sed -i -e '121 s/&//g' AmberTools/src/mdgx/Wrappers.c
sed -i -e '1698 s/UInt/UInt2/g' AmberTools/src/mdgx/Peptide.c

### Fix No. 3 - Add gfx90a support
##sed -i -e '894 s/ CACHE STRING/;gfx90a:xnack- CACHE STRING/g'\
##       -e '896 s/ CACHE STRING/;gfx90a CACHE STRING/g' cmake/FindHipCUDA.cmake
##
# Load dependencies
# It won't build with ROCm  5.7.3
module load rocm/5.2.3 craype-accel-amd-gfx90a 
module load py-numpy/1.26.1 python/3.11.6 boost/1.83.0-c++14-python parallel-netcdf/1.12.3  openblas/0.3.24 fftw/3.3.10  rocm/5.2.3  netcdf-c/4.9.2 netcdf-fortran/4.6.1
module load cmake/3.27.7
export FCFLAGS=-I$MPICH_DIR/include
PREFIX_DIR=$INSTALL_DIR

cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D COMPILER=AUTO \
    -D CMAKE_C_COMPILER=gcc \
    -D CMAKE_CXX_COMPILER=g++ \
    -D CMAKE_Fortran_COMPILER=gfortran \
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D CMAKE_C_FLAGS="-O3 "\
    -D CMAKE_Fortran_FLAGS="-O3 -fallow-argument-mismatch"  \
    -D HIP_ARCHITECTURES=gfx90a\
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


# The following cmake command will configure the software "correctly" despites returning a non-zero
# value and the following message.
# 
#CMake Error in src/pmemd/src/cuda/CMakeLists.txt:
#  HIP_ARCHITECTURES is empty for target "pmemd_cuda_SPFP_mpi".
#
# Ignore the error and continue

cmake \
    -D CMAKE_BUILD_TYPE=Release\
    -D COMPILER=AUTO\
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
    -D HIP_ARCHITECTURES=gfx90a\
    -D CMAKE_C_FLAGS="-O3 -fallow-argument-mismatch " \
    -D CMAKE_Fortran_FLAGS="-I${MPICH_DIR}/include -O3 -fallow-argument-mismatch" \
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
    -B build/amber 

cmake \
    --build build/amber \
    --target xblas_build \

cmake \
    --build build/amber \
    --target install \
    -j16


# Create the module file
mkdir $MODULE_DIR
echo """
-- Export environmental variables
local topDir='$INSTALL_DIR'

local binDir=topDir .. '/bin'
local libDir=topDir .. '/lib'
local libDir64=topDir .. '/lib64'
local incDir=topDir .. '/include'

-- Enforce explicit usage of versions by requiring full module name
if (mode() == 'load') then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        'Default module versions are disabled by your systems administrator.\n\n',
        '\tPlease load this module as <name>/<version>.\n'
    )
  end
end
load('rocm/5.2.3', 'craype-accel-amd-gfx90a')
load('py-numpy/1.26.1', 'python/3.11.6', 'boost/1.83.0-c++14-python', 'parallel-netcdf/1.12.3', 'openblas/0.3.24', 'fftw/3.3.10', 'netcdf-c/4.9.2', 'netcdf-fortran/4.6.1')

-- Update relevant PATH variables
prepend_path('PATH',binDir)
prepend_path('CPATH',incDir)
prepend_path('LD_LIBRARY_PATH',libDir)
prepend_path('LD_LIBRARY_PATH',libDir64)
setenv('AMBER_HOME',topDir)
""" > $MODULE_DIR/${AMBER_VERSION}.lua

