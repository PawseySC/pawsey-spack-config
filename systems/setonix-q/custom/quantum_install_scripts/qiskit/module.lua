-- -*- lua -*-

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : COMPILER_VERSION]])
whatis([[Build date : BUILD_DATE]])
whatis([[Path : INSTALL_PATH ]])

help([[ DESCRIP ]])

-- load dependencies
-- dependencies

family("py_qiskit")
conflict("py_qiskit")

local root = "INSTALL_PATH"

prepend_path("PYTHONPATH", root)

-- Enable GPU-aware MPI for Cray MPICH (required for multi-GPU/multi-node simulations)
setenv("MPICH_GPU_SUPPORT_ENABLED", "1")
-- Disable CUDA IPC fast path to avoid cuIpcOpenMemHandle errors on this platform
setenv("MPICH_GPU_IPC_ENABLED", "0")

local mpich_gnu_lib = "/opt/cray/pe/mpich/CRAY_MPICH_VER/ofi/gnu/GCC_MODULE_VER/lib"
setenv("MPICH_GNU", mpich_gnu_lib)
prepend_path("LD_LIBRARY_PATH", mpich_gnu_lib)

if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
