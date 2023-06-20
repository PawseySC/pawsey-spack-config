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

rocm_packages="
atmi
comgr
hip
hipblas
hipcub
hipfft
hipfort
hipify-clang
hip-rocclr
hipsolver
hipsparse
hsakmt-roct
hsa-rocr-dev
llvm-amdgpu
rccl
rocalution
rocblas
rocfft
rocm-bandwidth-test
rocm-clang-ocl
rocm-cmake
rocm-dbgapi
rocm-debug-agent
rocm-device-libs
rocm-gdb
rocminfo
rocm-openmp-extras
rocm-smi
rocm-smi-lib
rocm-tensile
rocm-validation-suite
rocprim
rocprofiler-dev
rocrand
rocsolver
rocsparse
rocthrust
roctracer-dev
roctracer-dev-api
rocwmma
aomp
rocm-opencl
rocmlir
rccl-tests
migraphx
miopengemm
miopen-hip
miopen-opencl
miopen-tensile
mivisionx
mlirmiopen
"

NVERSIONS=${#ROCM_VERSIONS[@]}

for package in $rocm_packages ; do
echo """
  $package:
      externals:"""
idx=0
while ((idx < NVERSIONS)); 
do
rocm_ver=${ROCM_VERSIONS[$idx]}
rocm_path=${ROCM_PATHS[$idx]}

echo """      - spec: $package@$rocm_ver
        prefix: $rocm_path"""
	(( idx = idx + 1 ))
done

echo "      buildable: false"
done

