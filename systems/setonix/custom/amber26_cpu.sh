AMBER_VERSION=26
DATE_TAG=2026.11
AMBER_SRC_DIR=/software/setonix/licensed_src/amber
BUILD_DIR=/tmp/amber-build
INSTALL_DIR=/software/setonix/${DATE_TAG}/custom/software/linux-sles15-zen3/gcc-14.2.0/amber/${AMBER_VERSION}
MODULE_DIR=/software/setonix/${DATE_TAG}/custom/modules/zen3/gcc/14.2.0/custom/amber
amber_tools_src=$AMBER_SRC_DIR/ambertools${AMBER_VERSION}.tar.bz2
pmemd_src=$AMBER_SRC_DIR/pmemd${AMBER_VERSION}.tar.bz2
PREFIX_DIR=$INSTALL_DIR

# xpmem.pc is not in the default PKG_CONFIG_PATH - need to add it
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH

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

# Load modules
module load python/3.11.6 py-numba/0.62.0rc2 py-scikit-learn/1.5.2 py-numpy/2.1.2 py-scipy/1.16.3 py-matplotlib/3.9.2 py-mpi4py/4.0.1-py3.11.6 py-pandas/2.2.3 py-setuptools/80.9.0-py3.11.6 
module load boost/1.88.0-c++11-python parallel-netcdf/1.12.3 openblas/0.3.28 fftw/3.3.10 netcdf-c/4.9.2 netcdf-fortran/4.6.1
module load cmake/3.31.9

# python venv for python packages required for installation not available as py- modules
mkdir -p ${INSTALL_DIR}
python3 -m venv ${INSTALL_DIR}/py-for-amber
source ${INSTALL_DIR}/py-for-amber/bin/activate
pip install --upgrade pip
pip install tk gemmi Bio rich freesasa sympy pydantic psutil networkx


# cmake configuration has to be run multiple times in succession before it succeeds
# Initial run of this cmake fails with MPI library error
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
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D OPENMP=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR \
    -S . \
    -B build/amber
# Run it again and it fails with tkinter error
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
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D OPENMP=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR \
    -S . \
    -B build/amber
# Third run succeeds
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
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D OPENMP=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
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
cd ../pmemd${AMBER_VERSION}_src
sed -i 's/python/python3/g' update_pmemd
./update_pmemd --update

# Removes dependency on libopen-pal, an OpenMPI related library. We do not have it on Cray Shasta,
# and I am not sure why it is needed.
sed -i '91d' src/pmemd/src/cuda/CMakeLists.txt

# cmake configuration has to be run multiple times in succession before it succeeds
# First run of cmake fails with MPI library error
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
    -D CMAKE_Fortran_FLAGS="-O3"  \
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR \
    -S . \
    -B build/amber
# Run again and it gets past previous MPI library error and fails with tkinter error
cmake \
    -D CMAKE_BUILD_TYPE=Release  \
    -D PMEMD_ONLY=ON \
    -D PMEMD_OMP_MPI=ON \
    -D FORCE_EXTERNAL_LIBS=netcdf \
    -D COMPILER=AUTO \
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
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
    -D CMAKE_INSTALL_PREFIX=$PREFIX_DIR \
    -S . \
    -B build/amber
# Third run succeeds
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
    -D CMAKE_Fortran_FLAGS="-O3"  \
    -D MPI_HOME=${MPICH_DIR} \
    -D MPI_mpi_LIBRARY=${MPICH_DIR}/lib/libmpi.so -D MPI_C_LIB_NAMES=mpi -D MPI_CXX_LIB_NAMES=mpi -D MPI_mpifort_LIBRARY=mpifort \
    -D MPI_C_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_C_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_CXX_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_CXX_LIBRARIES=${MPICH_DIR}/lib \
    -D MPI_Fortran_INCLUDE_PATH=${MPICH_DIR}/include -D MPI_Fortran_LIBRARIES=${MPICH_DIR}/lib \
    -D DISABLE_WARNINGS=ON \
    -D USE_FFT=ON \
    -D PYTHON_EXECUTABLE=$(which python3) \
    -D HAVE_TKINTER=ON \
    -D CHECK_UPDATES=OFF \
    -D DOWNLOAD_MINICONDA=OFF \
    -D MPI=ON \
    -D HIP=OFF \
    -D CUDA=OFF \
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
load('python/3.11.6', 'py-numba/0.62.0rc2', 'py-scikit-learn/1.5.2', 'py-numpy/2.1.2', 'py-scipy/1.16.3', 'py-matplotlib/3.9.2', 'py-mpi4py/4.0.1-py3.11.6', 'py-setuptools/80.9.0-py3.11.6', 'boost/1.88.0-c++11-python', 'parallel-netcdf/1.12.3', 'openblas/0.3.28', 'fftw/3.3.10', 'netcdf-c/4.9.2', 'netcdf-fortran/4.6.1')
-- Update relevant PATH variables
prepend_path('PATH',binDir)
prepend_path('CPATH',incDir)
prepend_path('LD_LIBRARY_PATH',libDir)
prepend_path('LD_LIBRARY_PATH',libDir64)
setenv('AMBER_HOME',topDir)
""" > $MODULE_DIR/${AMBER_VERSION}.lua