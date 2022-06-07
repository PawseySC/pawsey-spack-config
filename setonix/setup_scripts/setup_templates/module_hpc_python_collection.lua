-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : hpc-python-collection]])
whatis([[Version : VIEW_VERSION ]])

whatis([[Short description : A curated collection of Python packages for HPC. ]])
help([[A curated collection of Python packages for HPC.]])

whatis([[Curated packages : VIEW_ROOT_PACKAGES ]])

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
    if (myModuleUsrName() ~= myModuleFullName()) then
      LmodError(
          "Default module versions are disabled by your systems administrator.\n\n",
          "\tPlease load this module as <name>/<version>.\n"
      )
    end
end

local view_root = "VIEW_ROOT"
local view_python_version_major_minor = "VIEW_PYTHON_VERSION_MAJOR_MINOR"

prepend_path("PATH", view_root .. "/bin", ":")
prepend_path("LIBRARY_PATH", view_root .. "/lib", ":")
prepend_path("LIBRARY_PATH", view_root .. "/lib64", ":")
prepend_path("LD_LIBRARY_PATH", view_root .. "/lib", ":")
prepend_path("LD_LIBRARY_PATH", view_root .. "/lib64", ":")
prepend_path("CPATH", view_root .. "/include/python" .. view_python_version_major_minor, ":")
prepend_path("CPATH", view_root .. "/include", ":")
prepend_path("CMAKE_PREFIX_PATH", view_root , ":")
prepend_path("MANPATH", view_root .. "/share/man", ":")
prepend_path("ACLOCAL_PATH", view_root .. "/share/aclocal", ":")
prepend_path("PKG_CONFIG_PATH", view_root .. "/lib/pkgconfig", ":")
prepend_path("PKG_CONFIG_PATH", view_root .. "/lib64/pkgconfig", ":")

prepend_path("PYTHONPATH", view_root .. "/lib/python" .. view_python_version_major_minor .. "/site-packages", ":")

setenv("PYTHONUSERBASE", os.getenv("MYSOFTWARE").."/python")
prepend_path("PATH", os.getenv("PYTHONUSERBASE").."/bin")
