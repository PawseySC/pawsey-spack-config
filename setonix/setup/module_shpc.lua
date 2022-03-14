-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : SHPC_NAME]])
whatis([[Version : SHPC_VERSION]])

whatis([[Short description : Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins. ]])
help([[Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins.]])

load("PYTHON_MODULEFILE")
load("singularity/SINGULARITY_VERSION")

setenv("SINGULARITY_HPC_HOME","/software/setonix/DATE_TAG/SHPC_NAME")

prepend_path("PATH","/software/setonix/DATE_TAG/SHPC_NAME/bin")
prepend_path("PYTHONPATH","/software/setonix/DATE_TAG/SHPC_NAME/lib/pythonPYTHON_MAJORMINOR/site-packages")
