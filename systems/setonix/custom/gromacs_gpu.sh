#!/bin/bash -e

INSTALL_DIR=/software/projects/pawsey0001/setonix/2023.08/software/linux-sles15-zen3/gcc-12.2.0/gromacs-amd-gfx90a/2023.2
BUILD_DIR=$MYSCRATCH/gromacs-build

module load fftw/3.3.10 
module load cmake/3.24.3
module use /software/setonix/unsupported
module load rocm/5.7.1
module load craype-accel-amd-gfx90a 

export LLVM_DIR=$ROCM_HOME/llvm
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=$INSTALL_DIR/lib:$LIBRARY_PATH
export PATH=$INSTALL_DIR/bin:$PATH

[ -d $BUILD_DIR ] || mkdir -p $BUILD_DIR
cd $BUILD_DIR

# -----------------------------------------------------------------------------------------------------
#                                          boost
#------------------------------------------------------------------------------------------------------
[ -e boost_1_79_0_rc1.tar.gz ] || wget https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0_rc1.tar.gz
[ -e boost_1_79_0 ] || tar xf boost_1_79_0_rc1.tar.gz
cd boost_1_79_0
./bootstrap.sh
./b2 headers
./b2 -j128 cxxflags=-fPIC cflags=-fPIC install toolset=gcc --with=all --prefix="${INSTALL_DIR}"

# install hipsycl
# https://github.com/AdaptiveCpp/AdaptiveCpp/discussions/1077
wget https://github.com/AdaptiveCpp/AdaptiveCpp/archive/refs/tags/v23.10.0-alpha.tar.gz \
    && tar xf v23.10.0-alpha.tar.gz \
    && cd AdaptiveCpp-23.10.0-alpha \
    && mkdir build \
    && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_CXX_COMPILER=hipcc -DCMAKE_C_COMPILER=hipcc -DWITH_SSCP_COMPILER=OFF .. \
    && make -j128 && make install

echo "AdaptiveCPP installed."
cd $BUILD_DIR

# install plumed
git clone https://github.com/plumed/plumed2.git \
    && cd plumed2 \
    && git checkout ae54bc52a4727872a2b6c235646fc74dc7ef7928\
    && ./configure --prefix=$INSTALL_DIR \
    && make -j128 \
    && make install

cd $BUILD_DIR

# install gromacs
wget https://ftp.gromacs.org/gromacs/gromacs-2023.2.tar.gz
rm -rf gromacs-2023.2
tar xf gromacs-2023.2.tar.gz 
cd gromacs-2023.2 
sed -i "s|MPIX_Query_cuda_support()|0|g" ./src/gromacs/utility/mpiinfo.cpp
plumed patch -p -e "gromacs-2023.2"
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DBUILD_TESTING:BOOL=OFF '-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON' -DCMAKE_CXX_FLAGS="-L${MPICH_DIR}/lib -lmpi -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_hsa" \
       '-DGMX_GPU=SYCL' '-DGMX_SYCL_HIPSYCL=ON' -DHIPSYCL_TARGETS='hip:gfx90a' '-DGMX_MPI:BOOL=ON' -DMPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpi \
       '-DCMAKE_C_COMPILER=hipcc' '-DCMAKE_CXX_COMPILER=hipcc' '-DMPI_C_COMPILER=cc' '-DMPI_CXX_COMPILER=CC' '-DGMX_INSTALL_LEGACY_API=ON' '-DGMX_HWLOC:BOOL=ON' '-DGMX_EXTERNAL_LAPACK:BOOL=OFF'\
       '-DGMX_EXTERNAL_BLAS:BOOL=OFF' '-DGMX_SIMD=AVX2_256' '-DGMX_USE_RDTSCP:BOOL=ON' '-DGMX_OPENMP:BOOL=ON' '-DGMX_CYCLE_SUBCOUNTERS:BOOL=OFF' '-DGMX_FFT_LIBRARY=fftw3' '-DGMX_VERSION_STRING_OF_FORK=pawsey'\
       .. \
    && make -j 128 && make install

