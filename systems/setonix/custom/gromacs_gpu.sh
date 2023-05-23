#!/bin/bash
cd Gromacs
module load python/3.9.15
module load cmake/3.21.4
module load rocm/5.4.3  fftw/3.3.9  
export LDFLAGS="-L${MPICH_DIR}/lib -lmpi"
export CFLAGS="-I/${MPICH_DIR}/include -Ofast -L${MPICH_DIR}/lib -lmpi -fPIC -lm"
export CXXFLAGS="-std=c++11 -I/${MPICH_DIR}/include -Ofast -L${MPICH_DIR}/lib -fPIC -lmpi -lm"
INSTALL_DIR="/software/setonix/2022.11/custom/software/zen3/gcc/12.1.0/gromacs-amd-gfx90a/2023.01"
# going to build plumed just for this gromacs
git clone https://github.com/plumed/plumed2.git
cd plumed2
git checkout 6745c8378f62f
./configure --prefix=${INSTALL_DIR} CXXFLAGS="-O3 -funroll-loops" CFLAGS="-O3 -funroll-loops -ffast-math"
sed -i 's/CXXFLAGS_NOOPENMP=-O3 -funroll-loops/CXXFLAGS_NOOPENMP=-O3 -funroll-loops -ffast-math/g' Makefile.conf
make -j 64 install
cd ..

export PATH="${INSTALL_DIR}/bin:$PATH"
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib64:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:${LD_LIBRARY_PATH}"

plumed patch -p -e gromacs-2022 -m shared
mkdir build
cd build
cmake -DBUILD_SHARED_LIBS=on -DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpi  -DMPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so \
        -DCMAKE_BUILD_TYPE=Release \
        -DGMX_BUILD_OWN_FFTW=OFF \
        -DGMX_BUILD_FOR_COVERAGE=off \
        -DCMAKE_C_COMPILER=hipcc \
        -DCMAKE_CXX_COMPILER=hipcc \
	-DMPI_CXX_COMPILER=CC\
	-DMPI_C_COMPILER=cc\
        -DGMX_MPI=on\
        -DGMX_GPU=HIP \
        -DGMX_OPENMP=on \
        -DCMAKE_HIP_ARCHITECTURES="gfx90a" \
        -DGMX_SIMD=AVX2_256 \
        -DREGRESSIONTEST_DOWNLOAD=OFF \
        -DBUILD_TESTING=ON \
        -DGMXBUILD_UNITTESTS=ON \
        -DGMX_GPU_USE_VKFFT=on \
        -DHIP_HIPCC_FLAGS="-O3 --amdgpu-target=gfx90a --save-temps" \
        -DCMAKE_EXE_LINKER_FLAGS="-fopenmp" \
		-DGMX_HWLOC=ON \
		-DMPIEXEC=srun \
		-DMPIEXEC_NUMPROC_FLAG=-n \
		-DMPIEXEC_PREFLAGS="--export-all" \
		-DMPIEXEC_POSTFLAGS= \
		-DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" ..

make -j 64 install

# TODO: create modulefile
