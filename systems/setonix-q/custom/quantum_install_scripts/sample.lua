-- -*- lua -*-
-- Custom module for quantum codes
--

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : nvidia@24.11]])
whatis([[Build date : BUILD_DATE ]])
whatis([[Path : INSTALL_PATH ]])

help([[ DESCRIP ]])

-- load dependencies
-- dependencies
--

prepend_path("PATH", "INSTALL_PATH/bin", ":")
prepend_path("LIBRARY_PATH", "`/lib", ":")
prepend_path("LD_LIBRARY_PATH", "INSTALL_PATH/lib", ":")
prepend_path("CMAKE_PREFIX_PATH", "INSTALL_PATH/", ":")
prepend_path("PATH", "INSTALL_PATH/bin", ":")
prepend_path("CMAKE_PREFIX_PATH", "INSTALL_PATH/", ":")
prepend_path("PYTHONPATH", "INSTALL_PATH/lib/python3.10/site-packages", ":")

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
