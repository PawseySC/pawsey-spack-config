-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : pawsey_load_first]])

whatis([[Short description : A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])
helps([[A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])

-- Service variables for this module
-- 
local date_tag = "current"
-- 
-- NOTE: all definitions below need to be kept in sync with the
-- corresponding values found in `variables.sh` in this same directory
-- 
-- This is handy for testing, as it is the only one to tweak
local root_dir = "/software/setonix/" .. date_tag -- "ROOT_DIR"
-- 
local shpc_modules_dir_short = "modules" -- SHPC_SPACKUSER_MODULES_DIR_SHORT"
local pawsey_modules_dir = "pawsey-modules" -- PAWSEY_MODULES_DIR"
-- 
-- These need to be checked at every OS update
local gcc_version  = "10.3.0" -- "GCC_VERSION"
local cce_version  = "12.0.1" -- CCE_VERSION"
local aocc_version = "3.0.0" -- AOCC_VERSION"

-- List of Spack module categories
-- update when new categories are added
local module_categories = {
  "astro-applications",
  "bio-applications",
  "applications",
  "libraries",
  "programming-languages",
  "utilities",
  "visualisation",
  "python-packages",
  "benchmarking",
  "dependencies"
}
-- Count how many categories
num_categories = 0
for _ in pairs(module_categories) do num_categories = num_categories + 1 end

-- Query CPU architecture
local host_cpu = subprocess("lscpu | grep 'Model name'")
if ( string.match(host_cpu, "7763") ~= nil ) then
  arch = "zen3"
else
  arch = "zen2"
end

-- Root directories for Spack modules
local spack_root = root_dir .. "/modules/" .. arch
local gcc_root  = spack_root .. "/gcc/" .. gcc_version
local cce_root  = spack_root .. "/cce/" .. cce_version
local aocc_root = spack_root .. "/aocc/" .. aocc_version

-- Add Spack modules to Cray Lmod hierarchy variables
for index = 1,num_categories do
  prepend_path("LMOD_CUSTOM_COMPILER_GNU_PREFIX", gcc_root .. "/" .. module_categories[index])
  prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_10_0_PREFIX", cce_root .. "/" .. module_categories[index])
  prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", aocc_root .. "/" .. module_categories[index])
end

-- Add SHPC modules to MODULEPATH
local shpc_root = root_dir .. "/containers/" .. shpc_modules_dir_short
prepend_path("MODULEPATH", shpc_root)

-- Add Spack/SHPC modules to MODULEPATH
local pawsey_modules_root = root_dir .. "/" .. pawsey_modules_dir
prepend_path("MODULEPATH", pawsey_modules_root)