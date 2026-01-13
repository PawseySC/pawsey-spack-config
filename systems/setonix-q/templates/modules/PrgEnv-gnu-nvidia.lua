-- -*- lua -*-
-- PrgEnv-gnu-nvidia: Combined GNU + NVIDIA programming environment

local MODULE_NAME = "PrgEnv-gnu-nvidia"
local MODULE_VERSION = "@VERSION@"

whatis([[Name : ]] .. MODULE_NAME)
whatis([[Version : ]] .. MODULE_VERSION)
whatis([[Short description : Combined GNU + NVIDIA programming environment]])
whatis([[Build date : @BUILD_DATE@]])

help([[
PrgEnv-gnu-nvidia: Combined NVIDIA + GCC programming environment

This module provides:
  - PrgEnv-nvidia for CUDA/GPU compilation (nvhpc compilers)
  - gcc-native-mixed for GCC compatibility (CPU codes, dependencies)
  - Cray PE components (craype, craype-arm-grace, craype-network-ofi, xpmem)
  - Access to both NVIDIA and GCC spack-installed modules

Loaded modules:
  PrgEnv-nvidia, gcc-native-mixed/@GCC_VERSION_MAJORMINOR@, craype, craype-arm-grace, 
  craype-network-ofi, xpmem

Unloaded modules:
  cray-libsci (may conflict with some packages)

]])

load("PrgEnv-nvidia")
load("gcc-native-mixed/@GCC_VERSION_MAJORMINOR@")
load("craype")
load("craype-arm-grace")
load("craype-network-ofi")
load("xpmem")

unload("cray-libsci")

-- Add GCC spack modules (NVIDIA path added by PrgEnv-nvidia handshake)
local gcc_spack_path = os.getenv("LMOD_CUSTOM_COMPILER_GNU_@GCC_COMPAT_VERSION@_PREFIX")
if gcc_spack_path and gcc_spack_path ~= "" then
    prepend_path("MODULEPATH", gcc_spack_path)
end