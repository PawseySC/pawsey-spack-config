-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : SHPC_NAME]])
whatis([[Version : SHPC_VERSION]])

whatis([[Short description : Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins. ]])
help([[Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins.]])

load("PYTHON_MODULEFILE")
load("SINGULARITY_MODULEFILE")

setenv("SINGULARITY_HPC_HOME","/software/joey/DATE_TAG/SHPC_INSTALL_DIR")

prepend_path("PATH","/software/joey/DATE_TAG/SHPC_INSTALL_DIR/bin")
prepend_path("PYTHONPATH","/software/joey/DATE_TAG/SHPC_INSTALL_DIR/lib/pythonPYTHON_MAJORMINOR/site-packages")
