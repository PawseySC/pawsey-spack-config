-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : shpc]])
whatis([[Version : 0.0.46]])

whatis([[Short description : Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins. ]])
help([[Local filesystem registry for containers (intended for HPC) using Lmod or Environement Modules. Works for users and admins.]])

-- TODO: this can be generated by Spack, when recipe available

load("python/3.9.7")
load("singularity/3.8.6")

setenv("SINGULARITY_HPC_HOME","/software/setonix/2022.01/shpc")

prepend_path("PATH","/software/setonix/2022.01/shpc/bin")
prepend_path("PYTHONPATH","/software/setonix/2022.01/shpc/lib/python3.9/site-packages")