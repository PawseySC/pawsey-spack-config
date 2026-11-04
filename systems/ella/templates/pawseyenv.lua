-- Ella's native GCC software tree; compiler modules do not use the Cray PE.
family("pawseyenv")

local prefix = "INSTALL_PREFIX"
local arch = "neoverse_v2"
local compiler = "gcc/GCC_VERSION"
local categories = { MODULE_LUA_CAT_LIST }

local function expose(path)
    if isDir(path) then
        prepend_path("MODULEPATH", path)
    end
end

setenv("PAWSEY_STACK_VERSION", "DATE_TAG")
setenv("PAWSEYENV_ARCH", arch)
prepend_path("MODULEPATH", "NVHPC_MODULE_PREFIX")
prepend_path("MODULEPATH", "MPI_MODULE_PATH")
prepend_path("MODULEPATH", pathJoin(prefix, "UTILITIES_MODULES_DIR"))

for _, target in ipairs({ arch, "aarch64" }) do
    for _, tree in ipairs({ compiler, "Core" }) do
        for _, category in ipairs(categories) do
            expose(pathJoin(prefix, "modules", target, tree, category))
        end
    end
end
expose(pathJoin(prefix, "CUSTOM_MODULES_DIR", arch, compiler, "CUSTOM_MODULES_SUFFIX"))

local project_root = pathJoin("USER_PERMANENT_FILES_PREFIX", os.getenv("PAWSEY_PROJECT"))
expose(pathJoin(project_root, "ella/DATE_TAG/modules", arch, compiler, "PROJECT_MODULES_SUFFIX"))
expose(pathJoin(project_root, os.getenv("USER"), "ella/DATE_TAG/modules", arch, compiler, "USER_MODULES_SUFFIX"))
