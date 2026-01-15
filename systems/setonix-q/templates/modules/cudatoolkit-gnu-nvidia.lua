--[[ CUDA Toolkit (GNU/NVIDIA) minimal module
     Paths-only: no compiler overrides, no NVHPC comm_libs/NCCL/nvshmem. ]]

family("cudatoolkit")
conflict("cudatoolkit")

-- Version metadata
local MOD_MAJOR_VERSION    = "12"
local MOD_MINOR_VERSION    = "6"
local SDK_MAJOR_VERSION    = "24"
local SDK_MINOR_VERSION    = "11"
local MOD_LEVEL            = MOD_MAJOR_VERSION .. "." .. MOD_MINOR_VERSION
local SDK_LEVEL            = SDK_MAJOR_VERSION .. "." .. SDK_MINOR_VERSION

local NVTARGET             = "Linux_aarch64"
local SDK_PATH             = "/opt/nvidia/hpc_sdk/" .. NVTARGET .. "/" .. SDK_LEVEL
local CUDATOOLKIT_CURPATH  = SDK_PATH .. "/cuda/" .. MOD_MAJOR_VERSION .. "." .. MOD_MINOR_VERSION
local MATH_LIBS_PATH       = SDK_PATH .. "/math_libs/" .. MOD_MAJOR_VERSION .. "." .. MOD_MINOR_VERSION
local NSIGHT_COMPUTE       = SDK_PATH .. "/profilers/Nsight_Compute/"
local NSIGHT_SYSTEMS       = SDK_PATH .. "/profilers/Nsight_Systems/"

help([[Lightweight CUDA Toolkit environment:
- Sets CUDA paths (bin/lib/include) for version ]] .. MOD_LEVEL .. [[.
- Does NOT change CC/CXX/FC or add NVHPC comm_libs/NCCL/nvshmem.
]])

whatis("CUDA Toolkit " .. MOD_LEVEL .. " (paths only; no compiler/MPI overrides; no NVHPC comm_libs)")

-- Core CUDA locations
setenv("CUDATOOLKIT_HOME", CUDATOOLKIT_CURPATH)
setenv("CUDA_HOME",        CUDATOOLKIT_CURPATH)
setenv("NVHPC_CUDA_HOME",  CUDATOOLKIT_CURPATH)

-- Paths: CUDA binaries and tools only
prepend_path("PATH",     CUDATOOLKIT_CURPATH .. "/bin")
prepend_path("PATH",     CUDATOOLKIT_CURPATH .. "/libnvvp")
prepend_path("PATH",     CUDATOOLKIT_CURPATH .. "/compute-sanitizer")
prepend_path("PATH",     NSIGHT_COMPUTE)
prepend_path("PATH",     NSIGHT_SYSTEMS .. "bin")
prepend_path("MANPATH",  CUDATOOLKIT_CURPATH .. "/doc/man")

-- Libraries: CUDA runtime/NVVM/CUPTI/math libs only
prepend_path("LD_LIBRARY_PATH", CUDATOOLKIT_CURPATH .. "/lib64")
prepend_path("LD_LIBRARY_PATH", CUDATOOLKIT_CURPATH .. "/nvvm/lib64")
prepend_path("LD_LIBRARY_PATH", CUDATOOLKIT_CURPATH .. "/extras/Debugger/lib64")
prepend_path("LD_LIBRARY_PATH", CUDATOOLKIT_CURPATH .. "/extras/CUPTI/lib64")
prepend_path("LD_LIBRARY_PATH", MATH_LIBS_PATH .. "/lib64")

prepend_path("CRAY_LD_LIBRARY_PATH", CUDATOOLKIT_CURPATH .. "/lib64")
prepend_path("CRAY_LD_LIBRARY_PATH", MATH_LIBS_PATH .. "/lib64")

-- Includes
prepend_path("CPATH", CUDATOOLKIT_CURPATH .. "/include")
prepend_path("CPATH", CUDATOOLKIT_CURPATH .. "/nvvm/include")
prepend_path("CPATH", CUDATOOLKIT_CURPATH .. "/extras/Debugger/include")
prepend_path("CPATH", CUDATOOLKIT_CURPATH .. "/extras/CUPTI/include")
prepend_path("CPATH", MATH_LIBS_PATH .. "/include")

-- Cray compatibility helpers (no comm_libs)
setenv("CRAY_CUDATOOLKIT_VERSION", MOD_LEVEL)
setenv("CRAY_CUDATOOLKIT_DIR",     CUDATOOLKIT_CURPATH)
setenv("CRAY_CUDATOOLKIT_PREFIX",  CUDATOOLKIT_CURPATH)
setenv("XTPE_LINK_TYPE",           "dynamic")
setenv("CRAYPE_LINK_TYPE",         "dynamic")

setenv("CRAY_CUDATOOLKIT_INCLUDE_OPTS",
       "-I" .. CUDATOOLKIT_CURPATH .. "/include -I" .. CUDATOOLKIT_CURPATH .. "/nvvm/include -I" ..
       CUDATOOLKIT_CURPATH .. "/extras/Debugger/include -I" .. CUDATOOLKIT_CURPATH .. "/extras/CUPTI/include -I" ..
       MATH_LIBS_PATH .. "/include")

setenv("CRAY_CUDATOOLKIT_POST_LINK_OPTS",
       "-L" .. CUDATOOLKIT_CURPATH .. "/lib64 -L" .. CUDATOOLKIT_CURPATH .. "/nvvm/lib64 -L" ..
       CUDATOOLKIT_CURPATH .. "/extras/Debugger/lib64 -L" .. CUDATOOLKIT_CURPATH .. "/extras/CUPTI/lib64 -L" ..
       MATH_LIBS_PATH .. "/lib64 -Wl,--as-needed,-lcupti,-lcudart,--no-as-needed -lcuda")

-- Keep pkg-config hint but omit comm_libs
prepend_path("PKG_CONFIG_PATH", "/usr/lib64/pkgconfig")
