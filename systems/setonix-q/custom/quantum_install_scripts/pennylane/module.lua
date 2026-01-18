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

family("py_pennylane")
conflict("py_pennylane")

local root = "INSTALL_PATH"

prepend_path("PYTHONPATH", root)
setenv("MPICH_GPU_SUPPORT_ENABLED", "1")
setenv("MPICH_GPU_IPC_ENABLED", "0")
local cray_mpich_dir = os.getenv("CRAY_MPICH_DIR") or "/opt/cray/pe/mpich/8.1.33/ofi/gnu/12"
local gtl_lib_path = os.getenv("GTL_LIB_PATH") or pathJoin(cray_mpich_dir, "lib")
prepend_path("LD_LIBRARY_PATH", gtl_lib_path)

if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
