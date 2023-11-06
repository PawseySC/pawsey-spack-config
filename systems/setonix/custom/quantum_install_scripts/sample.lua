-- -*- lua -*-
-- Custom module for quantum codes
--

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : gcc@12.2.0]])
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
-- prepend_path("PYTHONPATH", "/software/setonix/2023.08/software/linux-sles15-zen3/gcc-12.2.0/py-setuptools-59.4.0-x3ywpd6otzgbfcyp67iw67ckibsdqrnq/lib/python3.10/site-packages", ":")
-- setenv("PAWSEY_PY_NUMPY_HOME", "/software/setonix/2023.08/software/linux-sles15-zen3/gcc-12.2.0/py-numpy-1.23.4-tfvpg5jilocjyzthio3hqjlguab44lwt")

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
