#!/bin/bash
# Run on an Ella compute node: bash collect_system_info.sh > ella-system-info.txt 2>&1
# Standalone inventory: no installation, settings.sh, or Slurm submission.
# Version probes such as bzip2 --version must not wait for terminal input.
exec </dev/null

report()
{
    printf '\n### %s\n' "$*"
    "$@" 2>&1
}

report hostname -f
report cat /etc/os-release
report uname -a
report lscpu
report nvidia-smi
report nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv
report df -h /tmp "${MYSCRATCH:-/tmp}" "${MYSOFTWARE:-$HOME}"
printf '\n### Selected environment\n'
env | sort | grep -E '^(PAWSEY_CLUSTER|PAWSEY_PROJECT|MYSCRATCH|MYSOFTWARE|INSTALL_PREFIX|DATE_TAG|TOOLCHAIN_[A-Z_]+|NVHPC_[A-Z_]+|GCC_ROOT|CUDA_HOME|CUDA_PATH|MPI_HOME|HPCX_[A-Z_]+|MODULEPATH|CC|CXX|FC|CFLAGS|CXXFLAGS|CPPFLAGS|LDFLAGS|CPATH|LIBRARY_PATH|LD_LIBRARY_PATH)='

printf '\n### Active tools and resolved paths\n'
for tool in gcc g++ gfortran python3 make ld as curl wget tar gzip bzip2 m4 perl patch cmake ninja pkg-config nvcc nvc nvc++ nvfortran; do
    printf '\n%s: ' "$tool"
    tool_path=$(command -v "$tool") || { echo unavailable; continue; }
    printf '%s\n' "$tool_path"
    readlink -f "$tool_path"
    "$tool" --version 2>&1 | head -n 3
done
report /usr/bin/gcc -dumpfullversion
report /usr/bin/g++ -dumpfullversion
report /usr/bin/gfortran -dumpfullversion
report /usr/bin/python3 --version
report gcc -dumpmachine
report g++ -print-file-name=libstdc++.so
report ls -l /usr/include/stdio.h /usr/include/c++/*/iostream

if type module >/dev/null 2>&1; then
    (
        report module list
        # Only this subshell's MODULEPATH changes; retain the initial module list above.
        for path in /opt/nvidia/hpc_sdk/modulefiles /software/hpcx/2.20/modulefiles \
            /software/ella/*/toolchains/modules /software/ella/*/toolchains/nvhpc-*/modulefiles \
            /software/ella/software/*/nvhpc-*/modulefiles \
            "${TOOLCHAIN_MODULE_PREFIX:-}" "${NVHPC_MODULE_PREFIX:-}"; do
            [[ -d "$path" ]] && module use "$path"
        done
        report module -t avail
        report module show gcc nvhpc nvhpc-nompi hpcx-mt-ompi
        if module load hpcx-mt-ompi; then
            report module list
            report ompi_info --version
            report ompi_info --path prefix
            report ompi_info --config
            report ompi_info --param pmix all
            report ompi_info --param plm all
            report ompi_info --param ras all
            report mpicc --showme
            report mpifort --showme:command
            printf '\n### Open MPI CUDA support\n'
            ompi_info --parsable --all | grep -E '(mpi|opal)_built_with_cuda_support:value'
            report ucx_info -v
            report ucx_info -d
            [[ -n "${MPI_HOME:-}" ]] && report ldd "$MPI_HOME/lib/libmpi.so"
        fi
    )
else
    printf '\nModule command unavailable; rerun with bash -l to include modules.\n'
fi
report srun --version
report srun --mpi=list

printf '\n### Installed NVIDIA SDKs and library header versions\n'
for sdk in /opt/nvidia/hpc_sdk/Linux_aarch64/* \
    /software/ella/*/toolchains/nvhpc-*/Linux_aarch64/* \
    /software/ella/software/*/nvhpc-*/Linux_aarch64/* \
    "${NVHPC_INSTALL_PREFIX:-}/Linux_aarch64/"* \
    "${INSTALL_PREFIX:-}/toolchains/"nvhpc-*/Linux_aarch64/*; do
    [[ -d "$sdk/compilers" ]] || continue
    report "$sdk/compilers/bin/nvc" -V
    for nvcc in "$sdk"/cuda/*/bin/nvcc; do
        [[ -x "$nvcc" ]] && report "$nvcc" --version
    done
    report ls -l "$sdk"/math_libs/*/targets/sbsa-linux/lib/lib{cutensor,cublas,cufft,curand,cusolver,cusparse}.so* \
        "$sdk"/comm_libs/*/nccl/lib/libnccl.so*
    grep -EH '^#define[[:space:]]+.*(MAJOR|MINOR|PATCH|VER_BUILD|VERSION_CODE)' \
        "$sdk"/math_libs/*/targets/sbsa-linux/include/{cutensor,cublas_api,cufft,curand,cusolver_common,cusparse}.h \
        "$sdk"/comm_libs/*/nccl/include/nccl.h 2>/dev/null
done
printf '\n### Shared library inventory\n'
ldconfig -p 2>&1 | grep -E 'lib(pmi|pmix|mpi|cuda|nvidia|fabric|ibverbs|hwloc|numa|ssl|crypto|ffi|seccomp|z|stdc\+\+|gfortran)'
printf '\n### Installed RPM inventory (including development packages)\n'
rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' | sort
