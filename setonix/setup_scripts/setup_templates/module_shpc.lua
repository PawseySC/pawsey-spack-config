-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : SHPC_NAME]])
whatis([[Version : SHPC_VERSION]])

whatis([[Short description : Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins. ]])
help([[Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins.]])

load("PYTHON_MODULEFILE")
load("SINGULARITY_MODULEFILE")

setenv("PAWSEY_SHPC_HOME","/software/setonix/DATE_TAG/SHPC_INSTALL_DIR")

prepend_path("PATH","/software/setonix/DATE_TAG/SHPC_INSTALL_DIR/bin")
prepend_path("PYTHONPATH","/software/setonix/DATE_TAG/SHPC_INSTALL_DIR/lib/pythonPYTHON_MAJORMINOR/site-packages")

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
    if (myModuleUsrName() ~= myModuleFullName()) then
      LmodError(
          "Default module versions are disabled by your systems administrator.\n\n",
          "\tPlease load this module as <name>/<version>.\n"
      )
    end
end
