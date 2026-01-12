-- -*- lua -*-
-- Custom module for NVIDIA cuQuantum SDK
--

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : COMPILER_VERSION]])
whatis([[Build date : BUILD_DATE]])
whatis([[Path : INSTALL_PATH ]])

help([[ DESCRIP ]])

-- load dependencies
-- dependencies
--

-- Only one cuquantum version at a time
family("cuquantum")

-- cuQuantum environment variables
local root = "INSTALL_PATH"
setenv("CUQUANTUM_ROOT", root)
setenv("CUQUANTUM_DIR", root)

-- Component-specific roots (some tools look for these)
setenv("CUSTATEVEC_ROOT", root)
setenv("CUTENSORNET_ROOT", root)

-- MPI distributed interface (if present)
local mpi_lib = pathJoin(root, "distributed_interfaces/libcutensornet_distributed_interface_mpi.so")
if isFile(mpi_lib) then
    setenv("CUTENSORNET_COMM_LIB", mpi_lib)
end

-- Library paths
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "distributed_interfaces"))

-- Include paths
prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("C_INCLUDE_PATH", pathJoin(root, "include"))
prepend_path("CPLUS_INCLUDE_PATH", pathJoin(root, "include"))

-- CMake support
prepend_path("CMAKE_PREFIX_PATH", root)

-- pkg-config support
if isDir(pathJoin(root, "lib/pkgconfig")) then
    prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
end

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
