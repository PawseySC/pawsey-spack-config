-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : spack]])
whatis([[Version : SPACK_VERSION]])

whatis([[Short description : A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments. ]])
help([[A package management tool designed to support multiple versions and configurations of software on a wide variety of platforms and environments.]])

load("PYTHON_MODULEFILE")

setenv("PAWSEY_SPACK_HOME","INSTALL_PREFIX/spack")

-- Define logs directory
local user = os.getenv("USER")
if ( user == "spack" ) then
  setenv("SPACK_LOGS_BASEDIR", "INSTALL_PREFIX/software/" .. user .. "/logs")
else
  setenv("SPACK_LOGS_BASEDIR", "USER_PERMANENT_FILES_PREFIX/" .. os.getenv("PAWSEY_PROJECT") .. "/" .. user .. "/setonix/DATE_TAG/software/" .. user .. "/logs")
end

-- Lmod 8.6+ has a function to source shell files in an unloadable way
-- see https://lmod.readthedocs.io/en/latest/050_lua_modulefiles.html
-- Joey has 8.3, so this is not usable

-- The following is NOT unloadable
execute{cmd=". INSTALL_PREFIX/spack/share/spack/setup-env.sh", modeA={"load"}}
-- Warn users about this fact
if (mode() == "load" or mode() == "unload") then
  LmodMessage("Note: when this module is unloaded, the shell environment will NOT revert to its original state, and retain some Spack settings. If you need the original shell environment, start a new shell session instead.")
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
