-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : spack]])
whatis([[Version : SPACK_VERSION]])

whatis([[Short description : A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments. ]])
help([[A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments.]])

load("PYTHON_MODULEFILE")

setenv("SPACK_HOME","/software/setonix/DATE_TAG/spack")

-- Lmod 8.6+ has a function to source shell files in an unloadable way
-- see https://lmod.readthedocs.io/en/latest/050_lua_modulefiles.html
-- Joey has 8.3, so this is not usable

-- The following is NOT unloadable
execute{cmd=". /software/setonix/DATE_TAG/spack/share/spack/setup-env.sh", modeA={"load"}}

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
    if (myModuleUsrName() ~= myModuleFullName()) then
      LmodError(
          "Default module versions are disabled by your systems administrator.\n\n",
          "\tPlease load this module as <name>/<version>.\n"
      )
    end
end
