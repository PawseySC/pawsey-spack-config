"""Run with `spack python -m unittest discover -s scripts/tests`."""

from contextlib import ExitStack
from pathlib import Path
import copy
import shutil
import subprocess
import tempfile
import unittest

try:
    import spack.config
    import spack.modules.lmod
    import spack.repo
    import spack.schema.env
    import spack.schema.modules
    import spack.spec
    import spack.store
    import spack.util.spack_yaml as yaml
    import spack.util.hash
    from spack.environment.list import SpecListParser
    from spack.package import InstallError
except ImportError:
    spack = None


ROOT = Path(__file__).resolve().parents[2]
COMPONENTS = {"hipblas-common", "hipblas", "hipfft", "hiprand", "hipsolver", "hipsparse",
              "hipcub", "hipfort", "hipsparselt"}


@unittest.skipIf(spack is None, "Run through Spack to exercise its native APIs")
class HipMathModules(unittest.TestCase):
    def setUp(self):
        self.contexts = ExitStack()
        self.addCleanup(self.contexts.close)
        self.work = Path(self.contexts.enter_context(tempfile.TemporaryDirectory()))
        self.contexts.enter_context(spack.repo.use_repositories(
            str(ROOT / "repo/nvidia"), str(ROOT / "repo"), override=False))
        self.contexts.enter_context(spack.store.use_store(self.work / "store"))

    def configuration(self, system):
        base = ROOT / "systems" / system
        site = spack.config.read_config_file(str(base / "configs/site/modules.yaml"))
        user = spack.config.read_config_file(str(base / "configs/spackuser/modules.yaml"))
        config = copy.deepcopy(spack.schema.merge_yaml(site, user))
        config["modules"]["default"]["roots"]["lmod"] = str(self.work / "modules")
        config["modules"]["default"]["lmod"]["core_compilers"] = ["gcc@13.3.1"]
        return base, config

    def test_both_stack_families_and_selectable_components_are_public_roots(self):
        for system in ("ella", "setonix-q"):
            base, _ = self.configuration(system)
            environment = yaml.load((base / "environments/nvidia_utils/spack.yaml").read_text())
            spack.config.validate(environment, spack.schema.env.schema)
            toolchains = yaml.load((base / "configs/site/toolchains.yaml").read_text())
            with spack.config.override("toolchains", toolchains["toolchains"]):
                parser = SpecListParser()
                parser.parse_definitions(data=environment["spack"]["definitions"])
                roots = parser.parse_user_specs(name="specs", yaml_list=environment["spack"]["specs"]).specs
            for hip, release in (("7.2.4", "7.2.4"), ("7.16.0", "10.1.0")):
                self.assertTrue(any(spec.name == "hip-math" and str(spec.versions) == hip
                                    for spec in roots))
                for name in COMPONENTS:
                    self.assertTrue(any(spec.name == name and str(spec.versions) == release
                                        for spec in roots),
                                    (system, name, release))
            commands = yaml.load((base / "rfm_files/pkg_cmds.yaml").read_text())["libraries"]
            for name in COMPONENTS | {"hip-math"}:
                command, options, expected = commands[name]
                self.assertTrue(expected)
                subprocess.run(["bash", "-n", "-c", command + " " + options], check=True)

    def test_nvidia_overrides_leave_the_amd_repository_available(self):
        self.assertEqual(spack.repo.PATH.get_pkg_class("hipblas").namespace, "pawsey_nvidia")
        repos = [repo for repo in spack.repo.PATH.repos if repo.namespace != "pawsey_nvidia"]
        with spack.repo.use_repositories(*repos):
            cls = spack.repo.PATH.get_pkg_class("hipblas")
            self.assertEqual(cls.namespace, "builtin")
            self.assertIn(spack.version.Version("6.3.0"), cls.versions)

    def test_cusparselt_rejects_other_binary_platforms(self):
        cls = spack.repo.PATH.get_pkg_class("cusparselt")
        for architecture in ("darwin-sequoia-aarch64", "linux-rocky9-x86_64"):
            spec = spack.spec.Spec("cusparselt@0.8.1.1 arch=" + architecture)
            with self.assertRaisesRegex(InstallError, "Linux SBSA"):
                cls(spec).install(spec, self.work / "unsupported")

    def spec(self, name, version, dependencies=(), namespace=None):
        namespace = namespace or ("setonix_repo" if name == "hip" else "pawsey_nvidia")
        parameters = {"cuda": True, "rocm": False} if name == "hip" or name in COMPONENTS else {}
        if name in COMPONENTS:
            parameters["cuda_arch"] = ["90"]
        node = {"name": name, "version": version, "namespace": namespace,
                "arch": {"platform": "linux", "platform_os": "rocky9", "target": "neoverse_v2"},
                "compiler": {"name": "gcc", "version": "13.3.1"},
                "parameters": parameters,
                "hash": spack.util.hash.b32_hash(name + version), "dependencies": [
                    {"name": spec.name, "hash": spec.dag_hash(),
                     "parameters": {"deptypes": kinds, "virtuals": []}}
                    for spec, kinds in dependencies]}
        nodes = [node]
        for dependency, _ in dependencies:
            nodes.extend(dependency.to_dict()["spec"]["nodes"])
        return spack.spec.Spec.from_dict({"spec": {"_meta": {"version": 4}, "nodes": nodes}})

    def test_umbrella_and_component_module_loading(self):
        lua = shutil.which("lua")
        if not lua:
            self.skipTest("Lua is needed to execute generated module guards")
        for system in ("ella", "setonix-q"):
            base, config = self.configuration(system)
            with spack.config.override("modules", config["modules"]), spack.config.override(
                    "config:template_dirs", [str(base / "templates")]):
                for hip_version, release in (("7.2.4", "7.2.4"), ("7.16.0", "10.1.0")):
                    cuda = self.spec("cuda", "13.1.0", namespace="builtin")
                    hip = self.spec("hip", hip_version, [(cuda, ["link", "run"])])
                    blas = self.spec("hipblas", release, [(hip, ["link", "run"])])
                    bundle = self.spec("hip-math", hip_version, [(blas, ["run"])])
                    for spec in (cuda, hip, blas, bundle):
                        spack.store.STORE.layout.create_install_directory(spec)
                        spack.store.STORE.db.add(spec, explicit=True)
                    modules = []
                    for spec in (blas, bundle):
                        spack.modules.lmod.configuration_registry.clear()
                        writer = spack.modules.lmod.LmodModulefileWriter(spec, "default", explicit=True)
                        self.assertFalse(writer.conf.hidden)
                        self.assertEqual(writer.layout.use_name, "libraries/" + spec.name + "/" + str(spec.version))
                        writer.write(overwrite=True)
                        modules.append(Path(writer.layout.filename))
                    self.assertIn('depends_on("hipblas/' + release + '")', modules[1].read_text())
                    self.assertIn('depends_on("hip/' + hip_version + '")', modules[0].read_text())
                    harness = self.work / "guard.lua"
                    harness.write_text('''
local module, expected, other = arg[1], arg[2], arg[3]
local active, action, pushes, loads = nil, "load", {}, 0
os.getenv = function(name) if name == "PAWSEY_HIP_STACK_VERSION" then return active end end
mode = function() return action end
LmodError = function(message) error(message) end
pushenv = function(name, value)
  assert(name == "PAWSEY_HIP_STACK_VERSION" and value == expected)
  if action == "load" then pushes[#pushes+1] = active or false; active = value
  else active = table.remove(pushes); if active == false then active = nil end end
end
depends_on = function() loads = loads + 1 end
whatis = function() end; help = function() end; setenv = function() end
myModuleUsrName = function() return "fixture/1" end
myModuleFullName = myModuleUsrName; isDir = function() return true end
prepend_path = function() end; append_path = function() end
remove_path = function() end; unsetenv = function() end
dofile(module); dofile(arg[4])
action = "unload"; dofile(module); assert(active == expected)
dofile(arg[4]); assert(active == nil)
active, action, loads = other, "load", 0
local ok = pcall(dofile, module)
assert(not ok and active == other and loads == 0, "Mixed HIP stacks were accepted")
action = "unload"; assert(pcall(dofile, module), "Unload must bypass the load guard")
''')
                    other = "7.16.0" if hip_version == "7.2.4" else "7.2.4"
                    for module in modules:
                        companion = modules[1] if module == modules[0] else modules[0]
                        subprocess.run([lua, str(harness), str(module), hip_version, other,
                                        str(companion)], check=True)


if __name__ == "__main__":
    unittest.main()
