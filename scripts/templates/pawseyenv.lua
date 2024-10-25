-- -*- lua -*-
-- Module file created by Pawsey
--

--[[

    A set of variable definitions to handle software 
    modules on Setonix, including Lmod hierarchies for 
    compilers and CPU architectures. Note that this 
    module needs to be loaded before the compiler module.

]]--

-- For clusters that do not use Cray Lmod, prepend to
-- MODULEPATH. Otherwise, prepend to the input Cray Lmod
-- hierarchy variable.
function pawsey_prepend_path(cray_var, path)
  if arch == "aarch64" then
    prepend_path("MODULEPATH", path)
  else
    prepend_path(cray_var, path)
  end
end


-- Service variables for this module
-- 
--
local fh = assert(io.open(os.getenv("HOME") .. "/.pawsey_project", "r"))
local psc_sw_env_project = fh:read("l")
fh:close()
local psc_sw_env_user = os.getenv("USER")
-- 
-- NOTE: all definitions below need to be kept in sync with the
-- corresponding values found in `variables.sh` in this same directory
-- 
-- This is handy for testing, as it is the only one to tweak
local psc_sw_env_root_dir = "INSTALL_PREFIX"
-- 
local psc_sw_env_custom_modules_dir = "CUSTOM_MODULES_DIR"
local psc_sw_env_utilities_modules_dir = "UTILITIES_MODULES_DIR"
local psc_sw_env_shpc_containers_modules_dir = "SHPC_CONTAINERS_MODULES_DIR"
--
local psc_sw_env_custom_modules_suffix = "CUSTOM_MODULES_SUFFIX"
local psc_sw_env_project_modules_suffix = "PROJECT_MODULES_SUFFIX"
local psc_sw_env_user_modules_suffix = "USER_MODULES_SUFFIX"
-- 
-- These need to be checked at every OS update
local psc_sw_env_gcc_version  = "GCC_VERSION"
local psc_sw_env_cce_version  = "CCE_VERSION"
local psc_sw_env_aocc_version = "AOCC_VERSION"

-- List of Spack module categories
-- update when new categories are added
local psc_sw_env_module_categories = {
  MODULE_LUA_CAT_LIST
}
-- Count how many categories
num_categories = 0
for _ in pairs(psc_sw_env_module_categories) do num_categories = num_categories + 1 end

-- Query CPU architecture
local psc_sw_env_host_cpu = subprocess("lscpu | grep 'Model name'")
if string.match(psc_sw_env_host_cpu, "Neoverse%-V2") ~= nil then
  arch = "aarch64"
elseif string.match(psc_sw_env_host_cpu, "7..3") ~= nil then
  arch = "zen3"
else
  arch = "zen2"
end


-- Add User modules to Cray Lmod hierarchy variables
-- Compiler modulefiles: /opt/cray/pe/lmod/modulefiles/core/<compiler>/<version>.lua
-- Cray service functions: /opt/cray/pe/admin-pe/lmod_scripts/lmodHierarchy.lua
local psc_sw_env_user_modules_root =  "USER_PERMANENT_FILES_PREFIX/" .. psc_sw_env_project .. "/" .. psc_sw_env_user .. "/setonix/DATE_TAG/modules/" .. arch
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX", psc_sw_env_user_modules_root .. "/gcc/" .. psc_sw_env_gcc_version .. "/" .. psc_sw_env_user_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_14_0_PREFIX", psc_sw_env_user_modules_root .. "/cce/" .. psc_sw_env_cce_version .. "/" .. psc_sw_env_user_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", psc_sw_env_user_modules_root .. "/aocc/" .. psc_sw_env_aocc_version .. "/" .. psc_sw_env_user_modules_suffix)


-- Add User SHPC modules to MODULEPATH
local psc_sw_env_shpc_user_root = "USER_PERMANENT_FILES_PREFIX/" .. psc_sw_env_project .. "/" .. psc_sw_env_user .. "/setonix/DATE_TAG/" .. psc_sw_env_shpc_containers_modules_dir
prepend_path("MODULEPATH", psc_sw_env_shpc_user_root)


-- Add Project modules to Cray Lmod hierarchy variables
local psc_sw_env_project_modules_root = "USER_PERMANENT_FILES_PREFIX/" .. psc_sw_env_project .. "/setonix/DATE_TAG/modules/" .. arch
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX", psc_sw_env_project_modules_root .. "/gcc/" .. psc_sw_env_gcc_version .. "/" .. psc_sw_env_project_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_14_0_PREFIX", psc_sw_env_project_modules_root .. "/cce/" .. psc_sw_env_cce_version .. "/" .. psc_sw_env_project_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", psc_sw_env_project_modules_root .. "/aocc/" .. psc_sw_env_aocc_version .. "/" .. psc_sw_env_project_modules_suffix)


-- Add Pawsey utility modules (including Spack/SHPC modulefiles) to MODULEPATH
local psc_sw_env_utilities_modules_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_utilities_modules_dir
prepend_path("MODULEPATH", psc_sw_env_utilities_modules_root)


-- Root directories for Spack modules
local psc_sw_env_spack_root = psc_sw_env_root_dir .. "/modules/" .. arch
local psc_sw_env_gcc_root  = psc_sw_env_spack_root .. "/gcc/" .. psc_sw_env_gcc_version
local psc_sw_env_cce_root  = psc_sw_env_spack_root .. "/cce/" .. psc_sw_env_cce_version
local psc_sw_env_aocc_root = psc_sw_env_spack_root .. "/aocc/" .. psc_sw_env_aocc_version
-- Add Spack modules to Cray Lmod hierarchy variables
-- Note: LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX comes from Lumi, on Joey there was no `_8_0`
for index = 1,num_categories do
  pawsey_prepend_path("LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX", psc_sw_env_gcc_root .. "/" .. psc_sw_env_module_categories[index])
  pawsey_prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_14_0_PREFIX", psc_sw_env_cce_root .. "/" .. psc_sw_env_module_categories[index])
  pawsey_prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", psc_sw_env_aocc_root .. "/" .. psc_sw_env_module_categories[index])
end


-- Add SHPC modules to MODULEPATH
local psc_sw_env_shpc_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_shpc_containers_modules_dir
prepend_path("MODULEPATH", psc_sw_env_shpc_root)


-- Add Pawsey custom modules to Cray Lmod hierarchy variables
local psc_sw_env_custom_modules_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_custom_modules_dir .. "/" .. arch
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX", psc_sw_env_custom_modules_root .. "/gcc/" .. psc_sw_env_gcc_version .. "/" .. psc_sw_env_custom_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_14_0_PREFIX", psc_sw_env_custom_modules_root .. "/cce/" .. psc_sw_env_cce_version .. "/" .. psc_sw_env_custom_modules_suffix)
pawsey_prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", psc_sw_env_custom_modules_root .. "/aocc/" .. psc_sw_env_aocc_version .. "/" .. psc_sw_env_custom_modules_suffix)

-- On aarch64 (non-Cray system), the default GCC is installed with Spack.
-- Consequently, the path to its module is determined by the system GCC version, which
-- is otherwise not used to build the software stack.
if arch == "aarch64" then
    local find = "find " .. psc_sw_env_root_dir .. " -type f -path '*/programming-languages/gcc/" .. psc_sw_env_gcc_version .. ".lua' -exec dirname {} \\; | sed 's:/programming-languages.*::'"

    local handle = io.popen(find)
    local psc_gcc_module_root = handle:read("*a"):gsub("%s+$", "")
    handle:close()

    if  psc_gcc_module_root ~= "" then
        prepend_path("MODULEPATH", psc_gcc_module_root .. "/programming-languages" )
    else
        LmodMessage("Path to module for GCC " .. psc_sw_env_gcc_version .. " not found.")
    end
end
