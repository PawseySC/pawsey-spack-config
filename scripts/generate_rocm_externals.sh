#!/bin/bash

ROCM_VERSIONS=(
"5.0.2"
"5.4.3"
)

ROCM_PATHS=(
"/opt/rocm-5.0.2"
"/software/setonix/2022.11/pawsey/software/rocm/rocm-5.4.3rev1"
)

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

echo """    - spec: $package@$rocm_ver
      prefix: $rocm_path"""
(( idx++ ))
done

echo "    buildable: false"
done

