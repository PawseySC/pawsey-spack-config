-- -*- lua -*-
-- Module file created by Pawsey
--

--[[

    A set of variable definitions to handle software 
    modules on Setonix, including Lmod hierarchies for 
    compilers and CPU architectures. Note that this 
    module needs to be loaded before the compiler module.

]]--

local shl_user = os.getenv("USER")
--
-- Query host general architecture
local host_arch = subprocess("uname -m")
local host_arch_name = ""
if ( string.match(host_arch, "aarch64") ) then
  host_arch_name = "aarch64"
  local modulepath = os.getenv("MODULEPATH") or ""
  for path in string.gmatch(modulepath, "[^:]+") do
    if string.match(path, "/software/setonix/") then
      remove_path("MODULEPATH", path)
    end
  end
end

-- Query CPU architecture
local psc_sw_env_host_cpu = subprocess("lscpu | grep 'Model name'")
if ( string.match(psc_sw_env_host_cpu, "Neoverse.V2") ) then
  -- Model name:                           Neoverse-V2
  arch = "neoverse_v2"
elseif ( string.match(psc_sw_env_host_cpu, "7..3") ~= nil ) then
  arch = "zen3"
else
  arch = "zen2"
end

-- Set basic properties
-- This is handy for testing, as it is the only one to tweak
local base_install_dir = "BASE_INSTALL_PREFIX"
local cluster = "CLUSTER"
local data_tag = "DATE_TAG"

-- Skip module path modifications for root (used during installation/admin tasks)
if not (shl_user == "root") then
-- Add Pawsey Lmod extensions (custom hooks, helper functions)
prepend_path('LMOD_PACKAGE_PATH', "/software/" .. cluster .. "/lmod-extras")

-- Service variables for this module
-- 
--
local fh = assert(io.open(os.getenv("HOME") .. "/.pawsey_project", "r"))
local psc_sw_env_project = fh:read("l")
fh:close()
local psc_sw_env_user = os.getenv("USER")
-- 

local psc_sw_env_root_dir = table.concat({base_install_dir, cluster, data_tag}, "/")
local psc_sw_env_clusarchdate = table.concat({cluster, data_tag}, "/")
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
local psc_sw_env_nvidia_version = "NVIDIA_VERSION"

-- List of Spack module categories
-- update when new categories are added
local psc_sw_env_module_categories = {
  MODULE_LUA_CAT_LIST
}
-- Count how many categories
num_categories = 0
for _ in pairs(psc_sw_env_module_categories) do num_categories = num_categories + 1 end

--------------------------------------------------------------------------------
-- Architecture and Compiler Configuration
--------------------------------------------------------------------------------
-- Define architecture groups: add new architectures here
local arch_groups = {
  zen = {"zen2", "zen3"},
  neoverse = {"neoverse_v2"}
}

-- Helper to check if current arch belongs to a group
local function is_arch(group)
  for _, a in ipairs(arch_groups[group] or {}) do
    if arch == a then return true end
  end
  return false
end

-- Compiler configurations: {lmod_var, directory, version, arch_groups}
-- To add a new compiler, add a row here
-- To change which architectures use a compiler, modify the archs list
local compilers = {
  {var = "LMOD_CUSTOM_COMPILER_GNU_12_0_PREFIX", dir = "gcc", version = psc_sw_env_gcc_version, archs = {"zen", "neoverse"}},
  {var = "LMOD_CUSTOM_COMPILER_CRAYCLANG_17_0_PREFIX", dir = "cce", version = psc_sw_env_cce_version, archs = {"zen"}},
  {var = "LMOD_CUSTOM_COMPILER_AOCC_4_1_PREFIX", dir = "aocc", version = psc_sw_env_aocc_version, archs = {"zen"}},
  {var = "LMOD_CUSTOM_COMPILER_NVIDIA_PREFIX", dir = "nvhpc", version = psc_sw_env_nvidia_version, archs = {"neoverse"}},
}

-- Helper to prepend compiler paths for matching architectures
local function prepend_compiler_paths(base_path, suffix)
  for _, c in ipairs(compilers) do
    for _, grp in ipairs(c.archs) do
      if is_arch(grp) then
        prepend_path(c.var, base_path .. "/" .. c.dir .. "/" .. c.version .. "/" .. suffix)
        break
      end
    end
  end
end

-- Helper to prepend compiler paths for Spack module categories (no suffix)
local function prepend_compiler_category_paths(base_path, category)
  for _, c in ipairs(compilers) do
    for _, grp in ipairs(c.archs) do
      if is_arch(grp) then
        prepend_path(c.var, base_path .. "/" .. c.dir .. "/" .. c.version .. "/" .. category)
        break
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Module Path Configuration
--------------------------------------------------------------------------------

-- Add User modules to Cray Lmod hierarchy variables
-- Compiler modulefiles: /opt/cray/pe/lmod/modulefiles/core/<compiler>/<version>.lua
-- Cray service functions: /opt/cray/pe/admin-pe/lmod_scripts/lmodHierarchy.lua
local psc_sw_env_user_modules_root = "USER_PERMANENT_FILES_PREFIX/" .. table.concat({psc_sw_env_project, psc_sw_env_user, psc_sw_env_clusarchdate, "modules", arch}, "/")
prepend_compiler_paths(psc_sw_env_user_modules_root, psc_sw_env_user_modules_suffix)

-- Add User SHPC modules to MODULEPATH
local psc_sw_env_shpc_user_root = "USER_PERMANENT_FILES_PREFIX/" .. table.concat({psc_sw_env_project, psc_sw_env_user, psc_sw_env_clusarchdate, psc_sw_env_shpc_containers_modules_dir}, "/")
prepend_path("MODULEPATH", psc_sw_env_shpc_user_root)
-- and the project-wide SHPC modules..
local psc_sw_env_shpc_project_root = "USER_PERMANENT_FILES_PREFIX/" .. table.concat({psc_sw_env_project, psc_sw_env_clusarchdate, psc_sw_env_shpc_containers_modules_dir}, "/")
prepend_path("MODULEPATH", psc_sw_env_shpc_project_root)

-- Add Project modules to Cray Lmod hierarchy variables
local psc_sw_env_project_modules_root = "USER_PERMANENT_FILES_PREFIX/" .. table.concat({psc_sw_env_project, psc_sw_env_clusarchdate, "modules", arch}, "/")
prepend_compiler_paths(psc_sw_env_project_modules_root, psc_sw_env_project_modules_suffix)

-- Add Pawsey utility modules (including Spack/SHPC modulefiles) to MODULEPATH
local psc_sw_env_utilities_modules_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_utilities_modules_dir
prepend_path("MODULEPATH", psc_sw_env_utilities_modules_root)

-- Add Spack modules to Cray Lmod hierarchy variables
local psc_sw_env_spack_root = psc_sw_env_root_dir .. "/modules/" .. arch
for index = 1, num_categories do
  prepend_compiler_category_paths(psc_sw_env_spack_root, psc_sw_env_module_categories[index])
end

-- Add SHPC modules to MODULEPATH
local psc_sw_env_shpc_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_shpc_containers_modules_dir
prepend_path("MODULEPATH", psc_sw_env_shpc_root)

-- Add Pawsey custom modules to Cray Lmod hierarchy variables
local psc_sw_env_custom_modules_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_custom_modules_dir .. "/" .. arch
prepend_compiler_paths(psc_sw_env_custom_modules_root, psc_sw_env_custom_modules_suffix)

-- Load default modules if on ARM (workaround until set as defaults by platforms)
if mode() == "load" and host_arch_name == "aarch64" then
  local gcc_version_major_minor = string.match(psc_sw_env_gcc_version, "(%d+%.%d+)")
  local old_quiet = os.getenv("LMOD_QUIET") or ""
  load("PrgEnv-nvidia")
  load("craype-arm-grace")
  pushenv("LMOD_QUIET", "1")
  load("gcc-native-mixed/" .. gcc_version_major_minor)
  pushenv("LMOD_QUIET", old_quiet)
  unload("cray-libsci")
end

end
-- if not root
