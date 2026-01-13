-- -*- lua -*-
-- Module file created by Pawsey
--

--[[

    A set of variable definitions to handle software 
    modules on Setonix, including Lmod hierarchies for 
    compilers and CPU architectures. Note that this 
    module needs to be loaded before the compiler module.

]]--


family("pawseyenv")

--------------------------------------------------------------------------------
-- Runtime Detection
--------------------------------------------------------------------------------
local shl_user = os.getenv("USER")

local host_arch = subprocess("uname -m")
local host_arch_name = ""
if ( string.match(host_arch, "aarch64") ) then
  host_arch_name = "aarch64"
end

local psc_sw_env_host_cpu = subprocess("lscpu | grep 'Model name'")
local arch
if ( string.match(psc_sw_env_host_cpu, "Neoverse.V2") ) then
  arch = "neoverse_v2"
elseif ( string.match(psc_sw_env_host_cpu, "7..3") ~= nil ) then
  arch = "zen3"
else
  arch = "zen2"
end

--------------------------------------------------------------------------------
-- Configuration: sed-replaced template values
--------------------------------------------------------------------------------
local install_prefix = "INSTALL_PREFIX"
local system = "SYSTEM"
local date_tag = "DATE_TAG"
local user_permanent_files_prefix = "USER_PERMANENT_FILES_PREFIX"

local psc_sw_env_custom_modules_dir = "CUSTOM_MODULES_DIR"
local psc_sw_env_utilities_modules_dir = "UTILITIES_MODULES_DIR"
local psc_sw_env_shpc_containers_modules_dir = "SHPC_CONTAINERS_MODULES_DIR"

local psc_sw_env_custom_modules_suffix = "CUSTOM_MODULES_SUFFIX"
local psc_sw_env_project_modules_suffix = "PROJECT_MODULES_SUFFIX"
local psc_sw_env_user_modules_suffix = "USER_MODULES_SUFFIX"

local psc_sw_env_gcc_version  = "GCC_VERSION"
local psc_sw_env_cce_version  = "CCE_VERSION"
local psc_sw_env_aocc_version = "AOCC_VERSION"
local psc_sw_env_nvidia_version = "NVIDIA_VERSION"

local psc_sw_env_module_categories = {
  MODULE_LUA_CAT_LIST
}

--------------------------------------------------------------------------------
-- Architecture and Compiler Configuration
--------------------------------------------------------------------------------
local arch_groups = {
  zen = {"zen2", "zen3"},
  neoverse = {"neoverse_v2"}
}

local function is_arch(group)
  for _, a in ipairs(arch_groups[group] or {}) do
    if arch == a then return true end
  end
  return false
end

local compilers = {
  {var = "LMOD_CUSTOM_COMPILER_GNU_GCC_LMOD_VERSION_PREFIX", dir = "gcc", version = psc_sw_env_gcc_version, archs = {"zen", "neoverse"}},
  {var = "LMOD_CUSTOM_COMPILER_CRAYCLANG_CCE_LMOD_VERSION_PREFIX", dir = "cce", version = psc_sw_env_cce_version, archs = {"zen"}},
  {var = "LMOD_CUSTOM_COMPILER_AOCC_AOCC_LMOD_VERSION_PREFIX", dir = "aocc", version = psc_sw_env_aocc_version, archs = {"zen"}},
  {var = "LMOD_CUSTOM_COMPILER_NVIDIA_NVIDIA_LMOD_VERSION_PREFIX", dir = "nvhpc", version = psc_sw_env_nvidia_version, archs = {"neoverse"}},
}

-- Clear any stale paths from previous sessions
for _, c in ipairs(compilers) do
  if c.version ~= "" then
    unsetenv(c.var)
  end
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
local function prepend_compiler_paths(base_path, suffix)
  for _, c in ipairs(compilers) do
    if c.version ~= "" then
      for _, grp in ipairs(c.archs) do
        if is_arch(grp) then
          prepend_path(c.var, base_path .. "/" .. c.dir .. "/" .. c.version .. "/" .. suffix)
          break
        end
      end
    end
  end
end

local function prepend_compiler_category_paths(base_path, category)
  for _, c in ipairs(compilers) do
    if c.version ~= "" then
      for _, grp in ipairs(c.archs) do
        if is_arch(grp) then
          prepend_path(c.var, base_path .. "/" .. c.dir .. "/" .. c.version .. "/" .. category)
          break
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Module Path Setup (skip for root)
--------------------------------------------------------------------------------
if not (shl_user == "root") then

setenv("PAWSEY_STACK_VERSION", date_tag)
setenv("PAWSEYENV_ARCH", arch)

-- Remove stale x86 paths if on ARM (temporary until all pawseyenv use family())
if host_arch_name == "aarch64" then
  local x86_patterns = {"/software/setonix/", "/zen3/", "/zen2/"}
  local modulepath = os.getenv("MODULEPATH") or ""
  for path in string.gmatch(modulepath, "[^:]+") do
    for _, pattern in ipairs(x86_patterns) do
      if string.match(path, pattern) then
        remove_path("MODULEPATH", path)
        break
      end
    end
  end
end

prepend_path('LMOD_PACKAGE_PATH', "/software/" .. system .. "/lmod-extras")

local fh = assert(io.open(os.getenv("HOME") .. "/.pawsey_project", "r"))
local psc_sw_env_project = fh:read("*l")
fh:close()

local psc_sw_env_system_datetag = table.concat({system, date_tag}, "/")

local num_categories = 0
for _ in pairs(psc_sw_env_module_categories) do num_categories = num_categories + 1 end

--------------------------------------------------------------------------------
-- Apply Module Paths
--------------------------------------------------------------------------------

-- User modules
local psc_sw_env_user_modules_root = user_permanent_files_prefix .. "/" .. table.concat({psc_sw_env_project, shl_user, psc_sw_env_system_datetag, "modules", arch}, "/")
prepend_compiler_paths(psc_sw_env_user_modules_root, psc_sw_env_user_modules_suffix)

-- User SHPC containers
local psc_sw_env_shpc_user_root = user_permanent_files_prefix .. "/" .. table.concat({psc_sw_env_project, shl_user, psc_sw_env_system_datetag, psc_sw_env_shpc_containers_modules_dir}, "/")
prepend_path("MODULEPATH", psc_sw_env_shpc_user_root)

-- Project SHPC containers
local psc_sw_env_shpc_project_root = user_permanent_files_prefix .. "/" .. table.concat({psc_sw_env_project, psc_sw_env_system_datetag, psc_sw_env_shpc_containers_modules_dir}, "/")
prepend_path("MODULEPATH", psc_sw_env_shpc_project_root)

-- Project modules
local psc_sw_env_project_modules_root = user_permanent_files_prefix .. "/" .. table.concat({psc_sw_env_project, psc_sw_env_system_datetag, "modules", arch}, "/")
prepend_compiler_paths(psc_sw_env_project_modules_root, psc_sw_env_project_modules_suffix)

-- Utility modules
local psc_sw_env_utilities_modules_root = install_prefix .. "/" .. psc_sw_env_utilities_modules_dir
prepend_path("MODULEPATH", psc_sw_env_utilities_modules_root)

-- Spack modules (per category)
local psc_sw_env_spack_root = install_prefix .. "/modules/" .. arch
for index = 1, num_categories do
  prepend_compiler_category_paths(psc_sw_env_spack_root, psc_sw_env_module_categories[index])
end

-- System SHPC containers
local psc_sw_env_shpc_root = install_prefix .. "/" .. psc_sw_env_shpc_containers_modules_dir
prepend_path("MODULEPATH", psc_sw_env_shpc_root)

-- Custom modules
local psc_sw_env_custom_modules_root = install_prefix .. "/" .. psc_sw_env_custom_modules_dir .. "/" .. arch
prepend_compiler_paths(psc_sw_env_custom_modules_root, psc_sw_env_custom_modules_suffix)
end
