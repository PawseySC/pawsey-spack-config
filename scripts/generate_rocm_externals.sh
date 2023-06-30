#!/bin/bash
if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

declare -A rocm_packages
rocm_packages=(
["atmi"]="lib/libatmi_runtime.so"
["comgr"]="lib/libamd_comgr.so"
["hip"]="lib/libamdhip64.so"
["hipblas"]="lib/libhipblas.so"
["hipcub"]="include/hipcub/hipcub.hpp"
["hipfft"]="lib/libhipfft.so"
["hipfort"]="lib/libhipfort-amdgcn.a"
["hipify-clang"]="bin/hipify-clang"
["hip-rocclr"]="lib/libamdhip64.so"
["hipsolver"]="lib/libhipsolver.so"
["hipsparse"]="lib/libhipsparse.so"
["hsakmt-roct"]="lib/libhsa-runtime64.so"
["hsa-rocr-dev"]="lib/libhsa-runtime64.so"
["llvm-amdgpu"]="llvm/lib/libclang.so"
["rccl"]="lib/librccl.so"
["rocalution"]="lib/librocalution_hip.so"
["rocblas"]="lib/librocblas.so"
["rocfft"]="lib/librocfft.so"
["rocm-bandwidth-test"]="bin/rocm-bandwidth-test"
["rocm-clang-ocl"]="bin/clang-ocl"
["rocm-cmake"]="lib/cmake"
["rocm-dbgapi"]="lib/librocm-dbgapi.so"
["rocm-debug-agent"]="share/doc/rocm-debug-agent"
["rocm-device-libs"]="amdgcn/bitcode/hip.bc"
["rocm-gdb"]="bin/rocgdb"
["rocminfo"]="bin/rocminfo"
["rocm-openmp-extras"]="share/doc/openmp-extras"
["rocm-smi"]="bin/rocm-smi"
["rocm-smi-lib"]="lib/librocm_smi64.so"
["rocprim"]="include/rocprim/rocprim.hpp"
["rocprofiler-dev"]="bin/rocprof"
["rocrand"]="lib/librocrand.so"
["rocsolver"]="lib/librocsolver.so"
["rocsparse"]="lib/librocsparse.so"
["rocthrust"]="include/thrust/rocthrust_version.hpp"
["roctracer-dev"]="lib/libroctracer64.so"
["roctracer-dev-api"]="include/roctracer/roctracer_roctx.h"
["rocwmma"]="include/rocwmma/rocwmma_coop.hpp"
["rocm-opencl"]="opencl/include/CL/opencl.h"
["rocm-clang-ocl"]="bin/clang-ocl"
)

# The following packages are not installed anywhere, hence don't know
# what file to check.
# rocmlir, rocm-tensile, rocm-validation-suite, aomp, rccl-tests,
# migraphxrocm-bandwidth-test


NVERSIONS=${#ROCM_VERSIONS[@]}

for package in "${!rocm_packages[@]}"; do
echo """
  $package:
      buildable: false"""
specs_string=""
nspecs=0
idx=0
while ((idx < NVERSIONS)); 
do
verification_file="${rocm_packages[$package]}"
rocm_ver=${ROCM_VERSIONS[$idx]}
rocm_path=${ROCM_PATHS[$idx]}
if [ -e "${rocm_path}/${verification_file}" ]; then
(( nspecs++ ))
specs_string="""$specs_string      - spec: $package@$rocm_ver
        prefix: $rocm_path
"""
fi
(( idx = idx + 1 ))
done
if (( nspecs > 0 )); then
echo """      externals:
$specs_string"""
fi
done

