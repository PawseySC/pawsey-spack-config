#!/bin/bash
# Run within an Ella allocation: INSTALL_GROUP=<group> bash systems/ella/bootstrap_toolchains.sh
set -euo pipefail

if [[ "$(uname -sm)" != "Linux aarch64" ]]; then
    echo "Ella's toolchains must be bootstrapped on Linux/aarch64." >&2
    exit 1
fi
ella_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export SYSTEM=ella
export PAWSEY_SPACK_CONFIG_REPO=$(cd -- "${ella_dir}/../.." && pwd)
source "${ella_dir}/settings.sh"

mkdir -p "${TOOLCHAIN_BUILD_PREFIX}" "${TOOLCHAIN_MODULE_PREFIX}/gcc"
cd "${TOOLCHAIN_BUILD_PREFIX}"
export CC="${BOOTSTRAP_CC}" CXX="${BOOTSTRAP_CXX}" FC="${BOOTSTRAP_FC}"

# Build GCC with the host compiler before NVIDIA configures its GCC integration.
if [[ ! -x "${GCC_INSTALL_PREFIX}/bin/gfortran" ]]; then
    curl --fail --location --retry 3 -o "gcc-${gcc_version}.tar.gz" \
        "https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.gz"
    tar -xzf "gcc-${gcc_version}.tar.gz"
    (cd "gcc-${gcc_version}" && ./contrib/download_prerequisites)
    mkdir -p "gcc-${gcc_version}-build"
    (
        cd "gcc-${gcc_version}-build"
        "../gcc-${gcc_version}/configure" --prefix="${GCC_INSTALL_PREFIX}" \
            --enable-languages=c,c++,fortran --disable-multilib
        make -j"${SLURM_CPUS_PER_TASK:-${NCPUS}}"
        make install
    )
fi

export PATH="${GCC_INSTALL_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${GCC_INSTALL_PREFIX}/lib64:${GCC_INSTALL_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export CC="${GCC_INSTALL_PREFIX}/bin/gcc" CXX="${GCC_INSTALL_PREFIX}/bin/g++" FC="${GCC_INSTALL_PREFIX}/bin/gfortran"
for compiler in gcc g++ gfortran; do
    "${GCC_INSTALL_PREFIX}/bin/${compiler}" -dumpfullversion | grep -Fx "${gcc_version}"
done

# Regenerate the module even when reusing an existing compiler installation.
cat > "${TOOLCHAIN_MODULE_PREFIX}/${gcc_module}.lua" <<EOF
whatis("GNU Compiler Collection ${gcc_version}")
conflict("gcc")
local root = "${GCC_INSTALL_PREFIX}"
setenv("GCC_ROOT", root)
setenv("GCC_VERSION", "${gcc_version}")
prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib64"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
EOF

nvhpc_root="${NVHPC_INSTALL_PREFIX}/Linux_aarch64/${nvidia_version}"
if [[ ! -x "${nvhpc_root}/compilers/bin/nvc" ]]; then
    archive="nvhpc_20${nvidia_version%.*}_${nvidia_version/./}_Linux_aarch64_cuda_multi"
    curl --fail --location --retry 3 -o "${archive}.tar.gz" \
        "https://developer.download.nvidia.com/hpc-sdk/${nvidia_version}/${archive}.tar.gz"
    tar -xzf "${archive}.tar.gz"
    (
        cd "${archive}"
        NVHPC_SILENT=true NVHPC_INSTALL_TYPE=single \
            NVHPC_INSTALL_DIR="${NVHPC_INSTALL_PREFIX}" \
            NVHPC_DEFAULT_CUDA="${nvhpc_cuda_version}" ./install
    )
fi
for compiler in nvc nvc++ nvfortran; do
    "${nvhpc_root}/compilers/bin/${compiler}" -V 2>&1 | grep -F " ${nvidia_version}-"
done
"${nvhpc_root}/cuda/${nvhpc_cuda_version}/bin/nvcc" --version
if [[ ! -f "${NVHPC_MODULE_PREFIX}/${nvhpc_module}" && ! -f "${NVHPC_MODULE_PREFIX}/${nvhpc_module}.lua" ]]; then
    echo "Missing NVIDIA module: ${NVHPC_MODULE_PREFIX}/${nvhpc_module}" >&2
    exit 1
fi

# Expose the MPI-free SDK module; keep Ella's existing HPC-X MPI separate.
printf '\nBootstrap complete. To expose the toolchain and MPI modules:\n'
printf 'module use %q %q %q\n' "${TOOLCHAIN_MODULE_PREFIX}" "${NVHPC_MODULE_PREFIX}" "${MPI_MODULE_PATH}"
printf 'Modules: %s, %s, %s\n' "${gcc_module}" "${nvhpc_module}" "${mpi_module}"
