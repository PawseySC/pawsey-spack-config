AMBER_VERSION=26
DATE_TAG=2026.11
AMBER_SRC_DIR=/software/setonix/licensed_src/amber
BUILD_DIR=/tmp/amber-build
INSTALL_DIR=/software/setonix/${DATE_TAG}/custom/software/linux-sles15-zen3/gcc-14.2.0/amber-amd-gfx90a/${AMBER_VERSION}
MODULE_DIR=/software/setonix/${DATE_TAG}/custom/modules/zen3/gcc/14.2.0/custom/amber-amd-gfx90a
amber_tools_src=$AMBER_SRC_DIR/ambertools${AMBER_VERSION}.tar.bz2
pmemd_src=$AMBER_SRC_DIR/pmemd${AMBER_VERSION}.tar.bz2
PREFIX_DIR=$INSTALL_DIR

# Extract source code
mkdir -p $BUILD_DIR
cd $BUILD_DIR
tar xf $amber_tools_src
tar xf $pmemd_src

##############
# AMBERTOOLS #
##############
# Apply any patches/updates to source code
cd ambertools${AMBER_VERSION}_src
sed -i 's/python/python3/g' update_amber
./update_amber --update

# Fix NVCC PIC flags
sed -i \
    -e 's/--compiler-options -fPIC/-fPIC/g' \
    -e 's/--compiler-options -fpic/-fpic/g' \
    AmberTools/src/cpptraj/CMakeLists.txt
# Add HIP defines to cpptraj targets
sed -i \
  -e 's/cpptraj_common_obj_cuda PRIVATE CUDA/cpptraj_common_obj_cuda PRIVATE CUDA __HIP_PLATFORM_HCC__ __HIP_PLATFORM_AMD__/' \
  -e 's/libcpptraj_cuda PRIVATE CUDA/libcpptraj_cuda PRIVATE CUDA __HIP_PLATFORM_HCC__ __HIP_PLATFORM_AMD__/' \
  -e 's/cpptraj\.cuda PRIVATE CUDA/cpptraj.cuda PRIVATE CUDA __HIP_PLATFORM_HCC__ __HIP_PLATFORM_AMD__/' \
  AmberTools/src/cpptraj/src/CMakeLists.txt
# Add HIP defines to kernel target
sed -i \
  '/cuda_add_library(cpptraj_cuda_routines STATIC ${CPPTRAJ_CUDA_SOURCES})/a target_compile_definitions(cpptraj_cuda_routines PRIVATE __HIP_PLATFORM_HCC__ __HIP_PLATFORM_AMD__)' \
  AmberTools/src/cpptraj/src/cuda_kernels/CMakeLists.txt
# Missing HIP mapping
sed -i '/#define cudaMalloc hipMalloc/a #define cudaMemset hipMemset' AmberTools/src/cpptraj/src/HipDefinitions.h


# Load modules
module load rocm/7.0.1 craype-accel-amd-gfx90a
module load py-numpy/2.1.2 python/3.11.6 boost/1.88.0-c++11-python parallel-netcdf/1.12.3 openblas/0.3.28 fftw/3.3.10 netcdf-c/4.9.2 netcdf-fortran/4.6.1
module load cmake/3.31.9

# configure, build, and install ambertools
cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D COMPILER=AUTO \
    -D FORCE_EXTERNAL_LIBS=netcdf \
    -D CMAKE_C_COMPILER=cc \
    -D CMAKE_CXX_COMPILER=CC \
    -D CMAKE_Fortran_COMPILER=ftn \
    -D MPI_C_COMPILER=cc \
    -D MPI_CXX_COMPILER=CC \
    -D MPI_Fortran_COMPILER=ftn \
    -D NetCDF_INCLUDES_F77=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D NetCDF_INCLUDES_F90=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D CMAKE_C_FLAGS="-O3 " \
    -D CMAKE_Fortran_FLAGS="-O3"  \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D BUILD_PYTHON=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D OPENMP=ON \
    -D AMDGPU_TARGETS=gfx90a \
    -D GPU_BUILD_TARGETS=gfx90a \
    -D GPU_TARGETS=gfx90a \
    -D HIP=ON \
    -D CUDA=OFF \
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
    -D COMPILER=AUTO \
    -D FORCE_EXTERNAL_LIBS=netcdf \
    -D CMAKE_C_COMPILER=cc \
    -D CMAKE_CXX_COMPILER=CC \
    -D CMAKE_Fortran_COMPILER=ftn \
    -D MPI_C_COMPILER=cc \
    -D MPI_CXX_COMPILER=CC \
    -D MPI_Fortran_COMPILER=ftn \
    -D NetCDF_INCLUDES_F77=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D NetCDF_INCLUDES_F90=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D CMAKE_C_FLAGS="-O3 " \
    -D CMAKE_Fortran_FLAGS="-O3" \
    -D MPI_HOME=${MPICH_DIR}\
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpi \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D BUILD_PYTHON=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D OPENMP=ON \
    -D AMDGPU_TARGETS=gfx90a \
    -D GPU_BUILD_TARGETS=gfx90a \
    -D GPU_TARGETS=gfx90a \
    -D HIP=ON \
    -D CUDA=OFF \
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
    --target xblas_build
cmake \
    --build build/amber \
    --target install \
    -j16

##########
# PMEMED #
##########
# Apply any patches/updates to source code
# NOTE: Critical patch needed for AMD GPU build of pmemd is included here. 
#       This update MUST be run for below configuration, build, and install commands to succeed
cd ../pmemd${AMBER_VERSION}_src
sed -i 's/python/python3/g' update_pmemd
./update_pmemd --update

# Removes dependency on libopen-pal, an OpenMPI related library. We do not have it on Cray Shasta,
# and I am not sure why it is needed.
sed -i '91d' src/pmemd/src/cuda/CMakeLists.txt

# Configure, build, and install pmemd
cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D PMEMD_ONLY=ON \
    -D PMEMD_OMP_MPI=ON \
    -D COMPILER=AUTO \
    -D FORCE_EXTERNAL_LIBS=netcdf \
    -D CMAKE_C_COMPILER=cc \
    -D CMAKE_CXX_COMPILER=CC \
    -D CMAKE_Fortran_COMPILER=ftn \
    -D MPI_C_COMPILER=cc \
    -D MPI_CXX_COMPILER=CC \
    -D MPI_Fortran_COMPILER=ftn \
    -D NetCDF_INCLUDES_F77=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D NetCDF_INCLUDES_F90=${PAWSEY_NETCDF_FORTRAN_HOME}/include \
    -D CMAKE_CXX_FLAGS="-O3 " \
    -D CMAKE_C_FLAGS="-O3 " \
    -D CMAKE_Fortran_FLAGS="-O3" \
    -D MPI_HOME=${MPICH_DIR}\
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -DMPI_C_LIB_NAMES=mpi -DMPI_CXX_LIB_NAMES=mpi \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D BUILD_PYTHON=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D AMDGPU_TARGETS=gfx90a \
    -D GPU_BUILD_TARGETS=gfx90a \
    -D GPU_TARGETS=gfx90a \
    -D HIP=ON \
    -D CUDA=OFF \
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
    --target install \
    -j16

# Create the module file
mkdir -p $MODULE_DIR
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
load('rocm/7.0.1', 'craype-accel-amd-gfx90a')
load('py-numpy/2.1.2', 'python/3.11.6', 'boost/1.88.0-c++11-python', 'parallel-netcdf/1.12.3', 'openblas/0.3.28', 'fftw/3.3.10', 'netcdf-c/4.9.2', 'netcdf-fortran/4.6.1')

-- Update relevant PATH variables
prepend_path('PATH',binDir)
prepend_path('CPATH',incDir)
prepend_path('LD_LIBRARY_PATH',libDir)
prepend_path('LD_LIBRARY_PATH',libDir64)
setenv('AMBER_HOME',topDir)
""" > $MODULE_DIR/${AMBER_VERSION}.lua