-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : pawsey_load_first]])

whatis([[Short description : A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])
helps([[A set of variable definitions to handle software modules on Setonix, including Lmod hierarchies for compilers and CPU architectures. Note that this module needs to be loaded before the compiler module.]])

-- Service variables for this module
-- TODO: these definitions need to be updated to their true values
-- appropriate values are defined in `variables.sh` in this same directory
local date_tag = "DATE_TAG"
local gcc_version  = "GCC_VERSION"
local cce_version  = "CCE_VERSION"
local aocc_version = "AOCC_VERSION"
local shpc_modules_dir_short = "SHPC_SPACKUSER_MODULES_DIR_SHORT"
local pawsey_modules_dir = "PAWSEY_MODULES_DIR"

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
local spack_root = "/software/setonix/" .. date_tag .. "/modules/" .. arch
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
local shpc_root = "/software/setonix/" .. date_tag .. "/containers/" .. shpc_modules_dir_short
prepend_path("MODULEPATH", shpc_root)

-- Add Spack/SHPC modules to MODULEPATH
local pawsey_modules_root = "/software/setonix/" .. date_tag .. "/" .. pawsey_modules_dir
