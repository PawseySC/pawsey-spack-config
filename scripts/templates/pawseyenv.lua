-- -*- lua -*-
-- Module file created by Pawsey
--

--[[

    A set of variable definitions to handle software
    modules on Setonix, including Lmod hierarchies for
    compilers and CPU architectures. This module must be
    loaded before the compiler module.

]]--


local user = os.getenv("USER")
if user == "root" then
  return
end

family("pawseyenv")

--------------------------------------------------------------------------------
-- Lmod Mode
--------------------------------------------------------------------------------
-- Configure variable caching or cleanup based on the current Lmod mode.
local current_mode = mode()


--------------------------------------------------------------------------------
-- Runtime Detection
--------------------------------------------------------------------------------
local host_arch = subprocess("uname -m")
local arch

if string.match(host_arch, "aarch64") then
  arch = "neoverse_v2"
else
  local cpu_model = subprocess("lscpu | grep 'Model name'")
  if string.match(cpu_model, "7..3") then
    arch = "zen3"
  else
    arch = "zen2"
  end
end

--------------------------------------------------------------------------------
-- Configuration: sed-replaced template values
--------------------------------------------------------------------------------
local install_prefix = "INSTALL_PREFIX"
local system = "SYSTEM"
local date_tag = "DATE_TAG"
local user_permanent_files_prefix = "USER_PERMANENT_FILES_PREFIX"

local custom_modules_dir = "CUSTOM_MODULES_DIR"
local utilities_modules_dir = "UTILITIES_MODULES_DIR"
local shpc_modules_dir = "SHPC_CONTAINERS_MODULES_DIR"

local custom_modules_suffix = "CUSTOM_MODULES_SUFFIX"
local project_modules_suffix = "PROJECT_MODULES_SUFFIX"
local user_modules_suffix = "USER_MODULES_SUFFIX"

local gcc_version = "GCC_VERSION"
local cce_version = "CCE_VERSION"
local aocc_version = "AOCC_VERSION"
local nvidia_version = "NVIDIA_VERSION"

local module_categories = {
  MODULE_LUA_CAT_LIST
}

--------------------------------------------------------------------------------
-- Architecture and Compiler Configuration
--------------------------------------------------------------------------------
local is_zen_arch = arch == "zen2" or arch == "zen3"
local compilers = {}

local function add_compiler(alias, compatible_version, dir, version, enabled)
  if enabled and version ~= "" then
    table.insert(compilers, {
      var = "LMOD_CUSTOM_COMPILER_"
        .. alias .. "_" .. compatible_version .. "_PREFIX",
      dir = dir,
      version = version
    })
  end
end

add_compiler("GNU", "GCC_LMOD_VERSION", "gcc", gcc_version, true)
add_compiler("CRAYCLANG", "CCE_LMOD_VERSION", "cce", cce_version, is_zen_arch)
add_compiler("AOCC", "AOCC_LMOD_VERSION", "aocc", aocc_version, is_zen_arch)
add_compiler(
  "NVIDIA", "NVIDIA_LMOD_VERSION", "nvhpc", nvidia_version,
  arch == "neoverse_v2"
)

--------------------------------------------------------------------------------
-- Cross-partition Cleanup
--------------------------------------------------------------------------------
local function contains(path, fragment)
  return string.find(path, fragment, 1, true) ~= nil
end

local function is_stale_partition_path(path)
  if arch == "neoverse_v2" then
    return contains(path, "/setonix/")
      or contains(path, "/zen2/")
      or contains(path, "/zen3/")
  elseif arch == "zen3" then
    return contains(path, "/setonix-q/")
      or contains(path, "/neoverse_v2/")
      or contains(path, "/zen2/")
  else
    return contains(path, "/setonix-q/")
      or contains(path, "/neoverse_v2/")
      or contains(path, "/zen3/")
  end
end

local function clean_path_variable(var, value)
  for path in string.gmatch(value or "", "[^:]+") do
    if is_stale_partition_path(path) then
      remove_path(var, path)
    end
  end
end

if current_mode == "load" or current_mode == "unload" then
  clean_path_variable("MODULEPATH", os.getenv("MODULEPATH"))
  clean_path_variable("LMOD_PACKAGE_PATH", os.getenv("LMOD_PACKAGE_PATH"))

  -- Compiler aliases vary between CPE releases, so inspect the active aliases
  -- instead of embedding aliases from another node image in this modulefile.
  local environment = subprocess("env") or ""
  for line in string.gmatch(environment, "[^\n]+") do
    local name, value = string.match(line, "^([^=]+)=(.*)$")
    if name and string.match(
      name,
      "^LMOD_CUSTOM_COMPILER_[A-Z0-9_]+_PREFIX$"
    ) then
      clean_path_variable(name, value)
    end
  end
end

local function prepend_compiler_paths(base_path, suffix)
  for _, compiler in ipairs(compilers) do
    local path = pathJoin(base_path, compiler.dir, compiler.version, suffix)
    if isDir(path) then
      prepend_path(compiler.var, path)
    end
  end
end

--------------------------------------------------------------------------------
-- Pawsey Project Detection
--------------------------------------------------------------------------------
-- The PAWSEY_PROJECT environment variable is required to determine 
-- project-specific module paths. This variable is set by the 'pawsey'
-- module, or may be set manually by the user if they are a member of
-- multiple projects. When the current Lmod mode is 'load' we check 
-- for the variable and raise an error if it is not set. 
-- The PAWSEYENV_PROJECT variable caches the project name to ensure
-- that the module can be unloaded cleanly if the PAWSEY_PROJECT 
-- variable is altered after loading this module.
local project
if current_mode == "load" then
  project = os.getenv("PAWSEY_PROJECT") or ""
  if project == "" then
    LmodError(
      "PAWSEY_PROJECT is not set. ",
      "Please load the 'pawsey' module or set the PAWSEY_PROJECT environment ",
      "variable to your project name."
    )
  end
  setenv("PAWSEYENV_PROJECT", project)
else
  project = os.getenv("PAWSEYENV_PROJECT") or os.getenv("PAWSEY_PROJECT")
end


--------------------------------------------------------------------------------
-- Apply Module Paths
--------------------------------------------------------------------------------
setenv("PAWSEY_STACK_VERSION", date_tag)
setenv("PAWSEYENV_ARCH", arch)

prepend_path("LMOD_PACKAGE_PATH", "/software/" .. system .. "/lmod-extras")

local system_stack = pathJoin(system, date_tag)

-- User modules
local user_modules_root = pathJoin(
  user_permanent_files_prefix, project, user, system_stack, "modules", arch
)
prepend_compiler_paths(user_modules_root, user_modules_suffix)

-- User SHPC containers
local user_shpc_root = pathJoin(
  user_permanent_files_prefix, project, user, system_stack, shpc_modules_dir
)
prepend_path("MODULEPATH", user_shpc_root)

-- Project SHPC containers
local project_shpc_root = pathJoin(
  user_permanent_files_prefix, project, system_stack, shpc_modules_dir
)
prepend_path("MODULEPATH", project_shpc_root)

-- Project modules
local project_modules_root = pathJoin(
  user_permanent_files_prefix, project, system_stack, "modules", arch
)
prepend_compiler_paths(project_modules_root, project_modules_suffix)

-- Utility modules
prepend_path("MODULEPATH", pathJoin(install_prefix, utilities_modules_dir))

-- Spack modules
local spack_root = pathJoin(install_prefix, "modules", arch)
for _, category in ipairs(module_categories) do
  prepend_compiler_paths(spack_root, category)
end

-- System SHPC containers
prepend_path("MODULEPATH", pathJoin(install_prefix, shpc_modules_dir))

-- Custom modules
local custom_modules_root = pathJoin(install_prefix, custom_modules_dir, arch)
prepend_compiler_paths(custom_modules_root, custom_modules_suffix)

local active_compiler = os.getenv("LMOD_FAMILY_COMPILER") or ""
-- isPending() is true while this module is being loaded, but false when Lmod
-- re-evaluates an already loaded module during `module refresh`.
-- We use this here to prevent the warning from being displayed when refreshing.
local pawseyenv_is_loading = isPending(myModuleFullName())
if current_mode == "load"
  and pawseyenv_is_loading
  and active_compiler ~= ""
then
  LmodWarning(
    "A compiler environment is already loaded (", active_compiler, "). ",
    "Run 'module refresh' to activate the architecture-specific module paths."
  )
end
