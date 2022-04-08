-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : pawsey_load_first]])

whatis([[Short description : A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])
helps([[A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])

-- Service variables for this module
-- 
local psc_sw_env_date_tag = "current"
-- 
-- NOTE: all definitions below need to be kept in sync with the
-- corresponding values found in `variables.sh` in this same directory
-- 
-- This is handy for testing, as it is the only one to tweak
local psc_sw_env_root_dir = "/software/setonix/" .. psc_sw_env_date_tag -- "ROOT_DIR"
-- 
local psc_sw_env_shpc_modules_dir_short = "modules" -- SHPC_SPACKUSER_MODULES_DIR_SHORT"
local psc_sw_env_pawsey_modules_dir = "pawsey-modules" -- PAWSEY_MODULES_DIR"
-- 
-- These need to be checked at every OS update
local psc_sw_env_gcc_version  = "10.3.0" -- "GCC_VERSION"
local psc_sw_env_cce_version  = "12.0.1" -- CCE_VERSION"
local psc_sw_env_aocc_version = "3.0.0" -- AOCC_VERSION"

-- List of Spack module categories
-- update when new categories are added
local psc_sw_env_module_categories = {
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
for _ in pairs(psc_sw_env_module_categories) do num_categories = num_categories + 1 end

-- Query CPU architecture
local psc_sw_env_host_cpu = subprocess("lscpu | grep 'Model name'")
if ( string.match(psc_sw_env_host_cpu, "7763") ~= nil ) then
  arch = "zen3"
else
  arch = "zen2"
end

-- Root directories for Spack modules
local psc_sw_env_spack_root = psc_sw_env_root_dir .. "/modules/" .. arch
local psc_sw_env_gcc_root  = psc_sw_env_spack_root .. "/gcc/" .. psc_sw_env_gcc_version
local psc_sw_env_cce_root  = psc_sw_env_spack_root .. "/cce/" .. psc_sw_env_cce_version
local psc_sw_env_aocc_root = psc_sw_env_spack_root .. "/aocc/" .. psc_sw_env_aocc_version

-- Add Spack modules to Cray Lmod hierarchy variables
-- Note: LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX comes from Lumi, on Joey there was no `_8_0`
for index = 1,num_categories do
  prepend_path("LMOD_CUSTOM_COMPILER_GNU_8_0_PREFIX", psc_sw_env_gcc_root .. "/" .. psc_sw_env_module_categories[index])
  prepend_path("LMOD_CUSTOM_COMPILER_CRAYCLANG_10_0_PREFIX", psc_sw_env_cce_root .. "/" .. psc_sw_env_module_categories[index])
  prepend_path("LMOD_CUSTOM_COMPILER_AOCC_3_0_PREFIX", psc_sw_env_aocc_root .. "/" .. psc_sw_env_module_categories[index])
end

-- Add SHPC modules to MODULEPATH
local psc_sw_env_shpc_root = psc_sw_env_root_dir .. "/containers/" .. psc_sw_env_shpc_modules_dir_short
prepend_path("MODULEPATH", psc_sw_env_shpc_root)

-- Add Spack/SHPC modules to MODULEPATH
local psc_sw_env_pawsey_modules_root = psc_sw_env_root_dir .. "/" .. psc_sw_env_pawsey_modules_dir
prepend_path("MODULEPATH", psc_sw_env_pawsey_modules_root)
