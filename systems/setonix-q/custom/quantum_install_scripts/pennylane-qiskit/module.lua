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

family("py_pennylane_qiskit")
conflict("py_pennylane_qiskit")

local root = "INSTALL_PATH"

prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))

prepend_path("CPATH", pathJoin(root, "include"))
prepend_path("C_INCLUDE_PATH", pathJoin(root, "include"))
prepend_path("CPLUS_INCLUDE_PATH", pathJoin(root, "include"))

prepend_path("PYTHONPATH", root)

if isDir(pathJoin(root, "lib/pkgconfig")) then
    prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))
end

if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
