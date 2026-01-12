-- -*- lua -*-
-- Custom module for NVIDIA cuTENSOR
--

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : nvidia@24.11]])
whatis([[Path : INSTALL_PATH ]])

help([[ DESCRIP ]])

-- load dependencies
-- dependencies
--

-- Only one cutensor version at a time
family("cutensor")

-- cuTensor environment variables
local root = "INSTALL_PATH"
setenv("CUTENSOR_ROOT", root)
setenv("CUTENSOR_DIR", root)

-- Library paths
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))

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
