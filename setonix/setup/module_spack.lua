-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : spack]])
whatis([[Version : 0.17.0]])

whatis([[Short description : A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments. ]])
help([[A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments.]])

-- Lmod 8.6+ has a function to source shell files in an unloadable way
-- see https://lmod.readthedocs.io/en/latest/050_lua_modulefiles.html
-- Joey has 8.3, so this is not usable

setenv("SPACK_HOME","/software/setonix/2022.01/spack")

load("cray-python/3.8.5.1")
-- The following is NOT unloadable
execute{cmd=". /software/setonix/2022.01/spack/share/spack/setup-env.sh", modeA={"load"}}
