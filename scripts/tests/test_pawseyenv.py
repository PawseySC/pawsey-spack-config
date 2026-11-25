"""Local module-generation checks; run with python3 -m unittest discover -s scripts/tests.

Requires Lua. The harness supplies Lmod's API so no cluster modules are changed.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
LUA_HARNESS = r'''
local module_file, system, arch, current_mode, selection = table.unpack(arg)
local project = selection == "missing" and "" or "project_a"
local environment = {
  USER = "test_user", PAWSEY_PROJECT = project,
  MODULEPATH = "/software/setonix/old/modules/x86_64/Core/dependencies:"
    .. "/software/setonix-q/old/modules/aarch64/Core/dependencies",
  LMOD_PACKAGE_PATH = "/software/setonix/lmod-extras:"
    .. "/software/setonix-q/lmod-extras"
}
if selection == "cached" then
  environment.PAWSEYENV_PROJECT = "project_a"
  environment.PAWSEY_PROJECT = "project_b"
end
local added, removed, warnings = {}, {}, 0
os.getenv = function(name) return environment[name] end
io.open = function() error("pawseyenv must use PAWSEY_PROJECT") end
function mode() return current_mode end
function family() end
function pathJoin(...)
  return table.concat({...}, "/"):gsub("/+", "/")
end
function isDir() return true end
function prepend_path(name, value)
  added[name] = added[name] or {}
  table.insert(added[name], value)
end
function remove_path(name, value)
  removed[name] = removed[name] or {}
  table.insert(removed[name], value)
end
function setenv(name, value) environment[name] = value end
function LmodError() error("PROJECT_REQUIRED") end
function LmodWarning() warnings = warnings + 1 end
function myModuleFullName() return "pawseyenv/2026.11" end
function isPending() return selection == "initial" end
function subprocess(command)
  if command == "uname -m" then
    return arch == "neoverse_v2" and "aarch64" or "x86_64"
  elseif command == "env" then
    return "LMOD_CUSTOM_COMPILER_GNU_99_0_PREFIX=" .. environment.MODULEPATH
  end
  return arch == "zen3" and "AMD EPYC 7A13" or "AMD EPYC 7H12"
end
if selection == "initial" or selection == "refresh" then
  environment.LMOD_FAMILY_COMPILER = "gcc"
end
local ok, err = pcall(dofile, module_file)
if selection == "missing" then
  assert(not ok and tostring(err):find("PROJECT_REQUIRED", 1, true), tostring(err))
  return
end
assert(ok, tostring(err))
assert(environment.PAWSEYENV_PROJECT == "project_a")
assert(environment.PAWSEYENV_ARCH == arch)
assert(environment.PAWSEY_STACK_VERSION == "2026.11")
local function has(values, fragment)
  for _, value in ipairs(values or {}) do
    if value:find(fragment, 1, true) then return true end
  end
  return false
end
local generic_arch = arch == "neoverse_v2" and "aarch64" or "x86_64"
assert(has(added.MODULEPATH, "/modules/" .. generic_arch .. "/Core/dependencies"))
assert(has(added.LMOD_CUSTOM_COMPILER_GNU_12_0_PREFIX, "/modules/" .. arch .. "/gcc/"))
assert(has(added.LMOD_CUSTOM_COMPILER_GNU_12_0_PREFIX, "/project_a/test_user/" .. system))
if system == "setonix" then
  assert(has(added.LMOD_CUSTOM_COMPILER_CRAYCLANG_21_0_PREFIX, "/cce/21.0.0/"))
  assert(has(added.LMOD_CUSTOM_COMPILER_AOCC_4_1_PREFIX, "/aocc/5.1.0/"))
  assert(added.LMOD_CUSTOM_COMPILER_NVIDIA_23_11_PREFIX == nil)
else
  assert(has(added.LMOD_CUSTOM_COMPILER_NVIDIA_23_11_PREFIX, "/nvhpc/25.9/"))
  assert(added.LMOD_CUSTOM_COMPILER_CRAYCLANG_21_0_PREFIX == nil)
end
local stale = generic_arch == "aarch64" and "/x86_64/" or "/aarch64/"
assert(has(removed.MODULEPATH, stale))
assert(has(removed.LMOD_CUSTOM_COMPILER_GNU_99_0_PREFIX, stale))
assert(not has(removed.MODULEPATH, "/" .. generic_arch .. "/"))
assert(warnings == (selection == "initial" and 1 or 0))
'''


@unittest.skipUnless(shutil.which("lua"), "Lua is required for the Lmod harness")
class PawseyenvTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="pawseyenv-test-")
        cls.directory = Path(cls.temporary.name)
        cls.harness = cls.directory / "lmod.lua"
        cls.harness.write_text(LUA_HARNESS)
        cls.modules = {}
        cls.environments = {}
        for system in ("setonix", "setonix-q"):
            output = cls.directory / f"{system}.lua"
            environment = dict(os.environ)
            environment.pop("__PSC_SETTINGS__", None)
            environment.update(
                SYSTEM=system,
                DATE_TAG="2026.11",
                INSTALL_PREFIX=str(cls.directory / system / "2026.11"),
                INSTALL_GROUP="test_group",
                USER="test_user",
                MYSOFTWARE=str(cls.directory / "user"),
                PAWSEY_PROJECT="project_a",
            )
            subprocess.run(
                ["bash", str(ROOT / "scripts/generate_pawseyenv.sh"), str(output)],
                env=environment, check=True, capture_output=True, text=True,
            )
            cls.modules[system] = output
            cls.environments[system] = environment

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def evaluate(self, system, arch, mode="load", selection="normal"):
        subprocess.run(
            ["lua", str(self.harness), str(self.modules[system]), system,
             arch, mode, selection],
            check=True, capture_output=True, text=True,
        )

    def test_compilers_core_modules_and_partition_cleanup(self):
        for system, arch in (("setonix", "zen2"), ("setonix", "zen3"),
                             ("setonix-q", "neoverse_v2")):
            with self.subTest(system=system, arch=arch):
                self.evaluate(system, arch)

    def test_unload_uses_cached_project_after_project_change(self):
        for system, arch in (("setonix", "zen3"), ("setonix-q", "neoverse_v2")):
            with self.subTest(system=system):
                self.evaluate(system, arch, "unload", "cached")

    def test_load_requires_project(self):
        self.evaluate("setonix", "zen3", selection="missing")

    def test_refresh_suppresses_existing_compiler_warning(self):
        self.evaluate("setonix", "zen3", selection="refresh")
        self.evaluate("setonix", "zen3", selection="initial")

    def test_top_level_generator_uses_the_same_configuration(self):
        for system in self.modules:
            with self.subTest(system=system):
                subprocess.run(
                    ["bash", str(ROOT / "generate_pawseyenv.sh"), system],
                    env=self.environments[system], cwd=self.directory,
                    check=True, capture_output=True, text=True,
                )
                output = self.directory / f"pawseyenv_{system}.lua"
                self.assertEqual(output.read_text(), self.modules[system].read_text())

    def test_date_is_resolved_before_loading_cpe_settings(self):
        shim = self.directory / "date-shim"
        shim.mkdir()
        date = shim / "date"
        date.write_text("#!/bin/sh\nprintf '2026.11\\n'\n")
        date.chmod(0o755)
        environment = dict(self.environments["setonix"])
        environment.pop("DATE_TAG")
        environment["PATH"] = str(shim) + os.pathsep + environment["PATH"]
        output = self.directory / "implicit-date.lua"
        subprocess.run(
            ["bash", str(ROOT / "scripts/generate_pawseyenv.sh"), str(output)],
            env=environment, check=True, capture_output=True, text=True,
        )
        self.assertEqual(output.read_text(), self.modules["setonix"].read_text())


if __name__ == "__main__":
    unittest.main()
