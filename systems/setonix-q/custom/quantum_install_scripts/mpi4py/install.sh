#!/bin/bash -e

script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh

# Validate required settings from settings.sh
if [[ -z "${DATE_TAG}" ]]; then
    echo "Error: DATE_TAG not set. Please source settings.sh first."
    exit 1
fi

# Load required modules
module purge
module load pawsey pawseytools pawseyenv/${DATE_TAG}
module load PrgEnv-gnu-nvidia
module load spack/${spack_ver}
module load gcc-native/${gcc_ver}
module load cray-mpich/${cray_mpich_ver}
module load cuda
module load python/${python_ver}

# Verify GTL library exists
GTL_LIB="${GTL_LIB_PATH}/libmpi_gtl_cuda.so"
if [[ ! -f "${GTL_LIB}" ]]; then
    echo "ERROR: GTL library not found at ${GTL_LIB}"
    exit 1
fi

# Generate MPI.cfg for mpi4py build
MPI_CFG="${script_dir}/MPI.cfg"
cat > "${MPI_CFG}" << EOF
[mpi]
libraries = mpi_gtl_cuda
library_dirs = ${GTL_LIB_PATH}
runtime_library_dirs = ${GTL_LIB_PATH}
EOF

# Install mpi4py via spack with GTL linkage
MPICH_GPU_SUPPORT_ENABLED=1 \
MPI4PY_BUILD_MPICFG="${MPI_CFG}" \
spack install --reuse -vvv -j 72 py-mpi4py@${tool_ver} %gcc@${gcc_module_ver}

spack module lmod refresh -y py-mpi4py@${tool_ver}
