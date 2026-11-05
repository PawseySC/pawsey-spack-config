"""Generate jobs with ReFrame 3.12; never submit them to a scheduler."""

import io
import os
from contextlib import ExitStack, redirect_stdout
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
try:
    import reframe
except ImportError:
    reframe = None
try:
    import spack.environment as ev
    import spack.paths
    import spack.repo
    import spack.spec
except ImportError:
    ev = None


def generate_jobs(system):
    import reframe.core.runtime as rt
    from reframe.core.schedulers import Job
    from reframe.frontend.loader import RegressionCheckLoader
    from install_manifest import atomic_write, source_digest

    repo = Path(__file__).resolve().parents[3]
    with tempfile.TemporaryDirectory(prefix="manifest-reframe-") as temporary:
        prefix = Path(temporary)
        source = prefix / "installation_metadata/environments/bootstrap"
        source.mkdir(parents=True)
        (source / "spack.yaml").write_text("spack: {specs: [python]}\n")
        (source / "spack.lock").write_text("{}\n")
        packages = {}
        for letter, compiler, version in (("a", "gcc", "13.3.1"), ("b", "nvhpc", "26.1")):
            scope = prefix / "modules/neoverse_v2" / compiler / version
            module = scope / "programming-languages/python/3.11.6.lua"
            module.parent.mkdir(parents=True)
            module.write_text("-- fixture\n")
            software = prefix / ("python-" + letter)
            software.mkdir()
            packages[letter * 32] = {
                "hash": letter * 32, "name": "python", "version": "3.11.6",
                "compiler": {"name": compiler, "version": version},
                "public": True, "external": False, "upstream": False,
                "module_name": "python/3.11.6", "module_path": str(module),
                "scope": str(scope), "prefix": str(software), "sources": ["bootstrap"],
                "autoloads": [],
            }
        roots = list(packages)
        for letter, has_module in (("c", True), ("d", False)):
            software = prefix / ("dependency-" + letter)
            software.mkdir()
            module = prefix / (".dependency-" + letter + ".lua") if has_module else None
            if module:
                module.write_text("-- hidden dependency\n")
            packages[letter * 32] = {
                "hash": letter * 32, "name": "dependency-" + letter, "version": "1.0",
                "compiler": None, "public": False, "external": False, "upstream": False,
                "prefix": str(software), "sources": ["bootstrap"], "autoloads": [],
                "module_name": ".dependency-" + letter + "/1.0" if has_module else None,
                "module_path": str(module) if has_module else None,
                "scope": str(prefix) if has_module else None,
            }
        output = prefix / "installation_metadata/spack_install_manifest.json"
        atomic_write(output, {
            "schema_version": 3, "status": "complete", "system": system,
            "install_prefix": str(prefix),
            "sources": {"bootstrap": {"path": str(source), "digest": source_digest(source),
                                      "roots": roots, "installed_hashes": list(packages)}},
            "packages": packages,
        })
        os.environ.update(
            SYSTEM=system, INSTALL_PREFIX=str(prefix), DATE_TAG="2026.11",
            INSTALLATION_METADATA_DIR=str(prefix / "installation_metadata"),
            PAWSEY_SPACK_CONFIG_REPO=str(repo), SPACK_ENV="bootstrap",
            SPACK_INSTALL_MANIFEST=str(output), gcc_version="13.3.1",
            python_version="3.11.6", reframe_version="3.12.0", spack_version="1.1.1")
        checks = repo / "systems" / system / "rfm_files"
        with rt.temp_runtime(str(checks / "rfm_settings.py"), system, {
                "systems/prefix": str(prefix / "results"), "systems/modules_system": "nomod"}):
            tests = RegressionCheckLoader([str(checks / "rfm_checks.py")]).load_all()
            assert len(tests) == 7, [test.display_name for test in tests]
            partitions = {part.name: part for part in rt.runtime().system.partitions}
            with patch.object(Job, "submit", return_value=None):
                for test in tests:
                    shell = type(test).__name__ in ("module_existence_check", "module_load_check")
                    name = ("shell" if shell else "compute") if system == "ella" else (
                        "quantum-shell" if shell else "quantum")
                    part = partitions[name]
                    test.setup(part, part.environs[0])
                    test.run()
                    script = Path(test.stagedir) / test.job.script_filename
                    subprocess.run(["bash", "-n", str(script)], check=True)
                    text = script.read_text()
                    if type(test).__name__ in ("module_load_check", "baseline_sanity_check"):
                        assert "_LMFILES_" in text and "manifest module verified:" in text, text
                        assert ("a" * 32 in test.tags) or ("b" * 32 in test.tags)
                        if "b" * 32 in test.tags:
                            expected = "nvhpc-nompi/26.1" if system == "ella" else "PrgEnv-nvidia"
                            assert expected in text, text
                    if type(test).__name__ == "concretise_check":
                        assert "spack -E python" in text and "reframe_concretization.py" in text, text
                        assert str(source) in text and "install_manifest/cli.py" not in text, text


@unittest.skipIf(reframe is None, "Requires ReFrame (validated with 3.12.0)")
class ReFrameInventoryTests(unittest.TestCase):
    def test_ella_jobs(self):
        subprocess.run([sys.executable, __file__, "ella"], check=True)

    def test_setonix_q_jobs(self):
        subprocess.run([sys.executable, __file__, "setonix-q"], check=True)


@unittest.skipIf(ev is None, "Run through Spack to exercise native environment assertions")
class ReFrameConcretizationTests(unittest.TestCase):
    def setUp(self):
        self.contexts = ExitStack()
        self.addCleanup(self.contexts.close)
        temporary = self.contexts.enter_context(tempfile.TemporaryDirectory(prefix="reframe-concretization-"))
        self.path = Path(temporary) / "environment"
        mock_repo = Path(spack.paths.prefix) / "var/spack/test_repos/spack_repo/builtin_mock"
        self.contexts.enter_context(spack.repo.use_repositories(str(mock_repo)))

    def concrete(self, version="0.8.13", letter="a"):
        return spack.spec.Spec.from_dict({"spec": {"_meta": {"version": 4}, "nodes": [{
            "name": "libelf", "version": version, "namespace": "builtin_mock",
            "arch": {"platform": "linux", "platform_os": "rocky9", "target": "neoverse_v2"},
            "compiler": {"name": "gcc", "version": "13.3.1"},
            "parameters": {}, "hash": letter * 32,
        }]}})

    def environment(self, abstract="libelf@0.8.13", concrete=None):
        environment = ev.create_in_dir(str(self.path), with_view=False)
        requested = spack.spec.Spec(abstract)
        environment.add(requested)
        environment._add_concrete_spec(requested, concrete or self.concrete())
        environment.write(regenerate=False)
        return environment

    def check(self):
        from reframe_concretization import check_concretization
        output = io.StringIO()
        with redirect_stdout(output):
            check_concretization(self.path)
        return output.getvalue()

    def test_saved_concretization_is_checked_without_modification(self):
        self.environment()
        original = {name: (self.path / name).read_bytes() for name in ("spack.yaml", "spack.lock")}
        self.assertIn("Concretization verified:", self.check())
        self.assertEqual(original, {name: (self.path / name).read_bytes() for name in original})

    def test_unconcretized_requested_root_fails(self):
        environment = self.environment()
        environment.add("libdwarf")
        environment.write(regenerate=False)
        with self.assertRaisesRegex(AssertionError, "Not every requested root"):
            self.check()

    def test_changed_request_with_same_root_count_fails(self):
        self.environment()
        manifest = self.path / "spack.yaml"
        manifest.write_text(manifest.read_text().replace("libelf@0.8.13", "libelf@0.8.12"))
        with self.assertRaisesRegex(AssertionError, "Not every requested root"):
            self.check()

    def test_concrete_root_must_satisfy_full_requested_spec(self):
        self.environment(concrete=self.concrete(version="0.8.12"))
        with self.assertRaisesRegex(AssertionError, "does not satisfy"):
            self.check()

    def test_native_matrix_expansion_is_checked(self):
        self.path.mkdir()
        (self.path / "spack.yaml").write_text(
            "spack:\n  specs:\n  - matrix: [[libelf], ['@0.8.12', '@0.8.13']]\n  view: false\n"
        )
        environment = ev.Environment(str(self.path))
        for letter, abstract in zip("ab", environment.user_specs):
            environment._add_concrete_spec(abstract, self.concrete(str(abstract.versions), letter))
        environment.write(regenerate=False)
        self.assertIn("(2 roots)", self.check())


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] in ("ella", "setonix-q"):
        generate_jobs(sys.argv[1])
    else:
        unittest.main()
