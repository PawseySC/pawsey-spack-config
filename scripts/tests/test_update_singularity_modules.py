"""Exercise deployment safety with a fake Spack store, never the live stack.

The driver and repository variant generator are real. Spack rendering and Lmod
are small test doubles; a real cluster staging run separately checks integration.
Run with: python3 -m unittest discover -s scripts/tests -p 'test_update_*.py'
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "update_singularity_modules.sh"
VERSION = "4.3.5"

# Only the commands needed for a module refresh are accepted. An accidental
# install/concretize invocation fails the test rather than touching any software.
FAKE_SPACK = r"""
import os
from pathlib import Path
import re
import sys

args = sys.argv[1:]
overrides = Path([args[i + 1] for i, a in enumerate(args) if a == "-C"][-1])
config = (overrides / "config.yaml").read_text()
stack = Path(re.search(r"root: '([^']+)'", config)[1]).parent
root = Path(re.search(r"lmod: '([^']+)'", (overrides / "modules.yaml").read_text())[1])
output = root / "zen3/gcc/14.2.0/utilities/singularityce/4.3.5.lua"
package = stack / "software/existing-singularityce"
if "find" in args and "module" not in args:
    if "9.9.9" not in " ".join(args):
        print("a" * 32, package, "gcc", "14.2.0")
elif "python" in args:
    print(output)
elif "module" in args and "refresh" in args:
    if not os.getenv("TEST_NO_RENDER"):
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            'whatis("test installed SingularityCE")\n'
            f'prepend_path("PATH", "{package}/bin")\n'
            'load("test-dependency")\n'
            'local singularity_bindpath = "/askapbuffer,/scratch,/software"\n'
            '-- add SLURM START\nsetenv("TEST_SLURM", "yes")\n-- add SLURM END\n'
            '-- add MPI START\nsetenv("TEST_MPI", "yes")\n-- add MPI END\n'
            '-- add GPUMPI START\nsetenv("TEST_GPU", "yes")\n-- add GPUMPI END\n'
            '-- add CRAY_PATHS START\nsetenv("TEST_CRAY", "yes")\n-- add CRAY_PATHS END\n'
            '-- add CURRENT_HOST_LD_PATH START\nsetenv("TEST_LD", "yes")\n'
            '-- add CURRENT_HOST_LD_PATH END\n'
        )
else:
    sys.exit("Unexpected Spack command: " + repr(args))
"""

SHELL_DRIVER = r"""
module() {
    if [ "$1" = use ]; then
        export TEST_MODULE_ROOT="$2"
    elif [[ " $* " == *" --location "* ]]; then
        printf '%s/%s.lua\n' "$TEST_MODULE_ROOT" "${@: -1}"
    fi
}
export -f module
exec bash "$@"
"""


@unittest.skipUnless(shutil.which("luac") and shutil.which("flock"), "requires luac and flock")
class ModuleUpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="singularity-module-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.stack = self.root / "stack/2026.09"
        self.scratch = self.root / "scratch"
        self.scratch.mkdir()
        self.source = self.stack / "modules/zen3/gcc/14.2.0/utilities/singularityce"
        self.variants = self.stack / "pawsey/modules/singularity"
        for directory in (self.source, self.variants):
            directory.mkdir(parents=True)
        self.originals = {}
        for name in ("askap-gpu", "askap", "mpi-gpu", "mpi", "nohost", "nompi"):
            self.originals[self.variants / f"{VERSION}-{name}.lua"] = f"-- original {name}\n"
        # The missing -slurm file checks that restore removes newly added files.
        self.originals[self.source / f"{VERSION}.lua"] = "-- original source\n"
        for path, content in self.originals.items():
            path.write_text(content)
            path.chmod(0o640)
        self.unselected = self.variants / "3.11.4-mpi.lua"
        self.unselected.write_text("-- keep this other version\n")
        (self.stack / "software/existing-singularityce/bin").mkdir(parents=True)
        for relative in (
            "spack/var/spack/repos/builtin/repos/spack_repo/builtin",
            "spack/var/spack/repos/pawsey",
        ):
            directory = self.stack / relative
            directory.mkdir(parents=True)
            (directory / "repo.yaml").write_text("repo: {}\n")
        helpers = self.stack / "pawsey/lmod-variable-fixes"
        helpers.mkdir(parents=True)
        for name in ("pawsey_fix_initial_bash.lua", "pawsey_init_bash"):
            (helpers / name).write_text("-- existing helper\n")
        executable = self.stack / "spack/bin/realspack"
        executable.parent.mkdir(parents=True)
        executable.write_text("#!/usr/bin/env python3\n" + textwrap.dedent(FAKE_SPACK))
        executable.chmod(0o755)
        self.environment = dict(os.environ, MYSCRATCH=str(self.scratch))

    def invoke(self, *arguments, success=True, version=VERSION):
        version_arguments = ["--version", version] if version is not None else []
        result = subprocess.run(
            [
                "bash", "-c", SHELL_DRIVER, "test-updater", str(SCRIPT),
                *version_arguments,
                "--date-tag", "2026.09", "--stack-prefix", str(self.stack), *arguments,
            ],
            env=self.environment, universal_newlines=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def run_directory(self):
        runs = list((self.scratch / "singularity-module-updates/2026.09").iterdir())
        self.assertEqual(len(runs), 1)
        return runs[0]

    def make_test_run(self):
        run = self.scratch / "singularity-module-updates/2026.09/existing-test-run"
        for live_path, content in self.originals.items():
            test_path = run / "tree" / live_path.relative_to(self.stack)
            test_path.parent.mkdir(parents=True, exist_ok=True)
            test_path.write_text(content)
            test_path.chmod(0o640)
        return run

    def assert_originals(self):
        for path, content in self.originals.items():
            self.assertEqual(path.read_text(), content)
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
        self.assertFalse((self.variants / f"{VERSION}-slurm.lua").exists())
        self.assertEqual(self.unselected.read_text(), "-- keep this other version\n")

    def test_default_staging_reuses_generator_without_live_writes(self):
        self.invoke()
        self.assert_originals()
        self.assertFalse(list(self.variants.glob(".*.bak")))
        run = self.run_directory()
        staged = run / "tree/pawsey/modules/singularity"
        self.assertEqual(len(list(staged.glob("*.lua"))), 7)
        mpi = (staged / f"{VERSION}-mpi.lua").read_text()
        self.assertIn('setenv("TEST_MPI", "yes")', mpi)
        for removed in ("TEST_SLURM", "TEST_GPU", "/askapbuffer", 'load("'):
            self.assertNotIn(removed, mpi)
        self.assertIn('setenv("TEST_GPU", "yes")', (staged / f"{VERSION}-mpi-gpu.lua").read_text())

    def test_apply_and_restore_preserve_originals_and_other_versions(self):
        self.invoke("--apply-live")
        run = self.run_directory()
        self.assertEqual(len(list(self.variants.glob(".*.bak"))), 6)
        self.assertEqual(len(list(self.source.glob(".*.bak"))), 1)
        for path in self.originals:
            self.assertEqual(path.stat().st_mode & 0o777, 0o640)
        self.assertTrue((self.variants / f"{VERSION}-slurm.lua").exists())
        self.invoke("--apply-live", "--restore", str(run))
        self.assert_originals()
        self.assertEqual((run / "deployment-state").read_text().strip(), "restored")
        self.assertEqual(len(list(self.variants.glob(".*.bak"))), 6)

    def test_explicit_version_can_differ_from_stack_settings(self):
        selected_version = "3.11.4"
        executable = self.stack / "spack/bin/realspack"
        executable.write_text(
            "#!/usr/bin/env python3\n"
            + textwrap.dedent(FAKE_SPACK).replace(VERSION, selected_version)
        )

        self.invoke(version=selected_version)

        run = self.run_directory()
        staged = run / "tree/pawsey/modules/singularity"
        modules = list(staged.glob("*.lua"))
        self.assertEqual(len(modules), 7)
        self.assertTrue(all(path.name.startswith(selected_version + "-") for path in modules))
        self.assertTrue((run / "tree" / self.source.relative_to(self.stack)
                         / f"{selected_version}.lua").is_file())
        self.assert_originals()

    def test_version_is_required_even_when_configured_in_settings(self):
        for arguments in ((), ("--apply-live",), ("--apply-live", "--restore", str(self.root))):
            with self.subTest(arguments=arguments):
                result = self.invoke(*arguments, version=None, success=False)
                self.assertIn("--version VERSION is required", result.stderr)
        self.assertFalse((self.scratch / "singularity-module-updates").exists())
        self.assert_originals()

    def test_invalid_or_empty_version_is_rejected_before_staging(self):
        for version in ("", "4.3.5-mpi", "../4.3.5"):
            with self.subTest(version=version):
                result = self.invoke(version=version, success=False)
                self.assertTrue(
                    "Missing value for --version" in result.stderr
                    or "Supply a numeric SingularityCE --version" in result.stderr,
                    result.stderr,
                )
        self.assertFalse((self.scratch / "singularity-module-updates").exists())
        self.assert_originals()

    def test_help_does_not_require_version(self):
        result = self.invoke("--help", version=None)
        self.assertIn("Required installed SingularityCE version; no default.", result.stdout)

    def test_suffix_labels_staged_modules_and_load_hint(self):
        result = self.invoke("--suffix", "recreated")
        run = self.run_directory()
        staged = run / "tree/pawsey/modules/singularity"
        modules = list(staged.glob("*.lua"))
        self.assertEqual(len(modules), 7)
        self.assertTrue(all(path.name.endswith("-recreated.lua") for path in modules))
        self.assertTrue((run / "tree" / self.source.relative_to(self.stack)
                         / f"{VERSION}-recreated.lua").is_file())
        self.assertIn(f"module load singularity/{VERSION}-mpi-recreated", result.stdout)
        self.assert_originals()

    def test_suffix_live_publication_and_restore_leave_originals_untouched(self):
        self.invoke("--suffix", "QA_2", "--apply-live")
        run = self.run_directory()
        self.assert_originals()
        self.assertEqual(len(list(self.variants.glob("*-QA_2.lua"))), 7)
        self.assertFalse(list(self.variants.glob(".*.bak")))
        source = self.source / f"{VERSION}-QA_2.lua"
        self.assertTrue(source.is_file())

        self.invoke("--apply-live", "--restore", str(run))

        self.assertFalse(list(self.variants.glob("*-QA_2.lua")))
        self.assertFalse(source.exists())
        self.assert_originals()

    def test_suffix_test_replacement_backs_up_and_restores_labelled_files(self):
        test_run = self.make_test_run()
        variants = test_run / "tree" / self.variants.relative_to(self.stack)
        source = test_run / "tree" / self.source.relative_to(self.stack)
        labelled_originals = {}
        for directory, name in (
            (variants, f"{VERSION}-mpi-recreated.lua"),
            (source, f"{VERSION}-recreated.lua"),
        ):
            path = directory / name
            path.write_text("-- previous labelled module\n")
            labelled_originals[path] = path.read_text()

        self.invoke("--suffix", "recreated", "--replace-in-test", str(test_run))
        update_run = next(
            path for path in test_run.parent.iterdir() if path != test_run
        )
        for path, content in labelled_originals.items():
            self.assertNotEqual(path.read_text(), content)
            self.assertEqual(
                next(path.parent.glob(f".{path.name}.*.bak")).read_text(), content
            )
        for live_path, content in self.originals.items():
            self.assertEqual(
                (test_run / "tree" / live_path.relative_to(self.stack)).read_text(), content
            )
        self.assert_originals()

        self.invoke("--replace-in-test", str(test_run), "--restore", str(update_run))
        for path, content in labelled_originals.items():
            self.assertEqual(path.read_text(), content)
        self.assertEqual(len(list(variants.glob("*-recreated.lua"))), 1)
        self.assert_originals()

    def test_invalid_suffix_is_rejected_before_staging(self):
        for suffix in ("../recreated", "-recreated", "two words", "a/b", ".hidden"):
            with self.subTest(suffix=suffix):
                result = self.invoke("--suffix", suffix, success=False)
                self.assertIn("--suffix must start", result.stderr)
        self.assertFalse((self.scratch / "singularity-module-updates").exists())
        self.assert_originals()

    def test_replace_in_test_backs_up_replaces_and_restores_without_live_writes(self):
        test_run = self.make_test_run()
        test_source = test_run / "tree" / self.source.relative_to(self.stack)
        test_variants = test_run / "tree" / self.variants.relative_to(self.stack)

        self.invoke("--replace-in-test", str(test_run))

        update_run = next(
            path for path in (self.scratch / "singularity-module-updates/2026.09").iterdir()
            if path != test_run
        )
        self.assertIn('setenv("TEST_MPI", "yes")', (test_variants / f"{VERSION}-mpi.lua").read_text())
        self.assertEqual(len(list(test_variants.glob(".*.bak"))), 6)
        self.assertEqual(len(list(test_source.glob(".*.bak"))), 1)
        self.assertEqual(
            next(test_variants.glob(f".{VERSION}-mpi.lua.*.bak")).read_text(),
            self.originals[self.variants / f"{VERSION}-mpi.lua"],
        )
        self.assertTrue((test_variants / f"{VERSION}-slurm.lua").exists())
        self.assert_originals()

        self.invoke("--replace-in-test", str(test_run), "--restore", str(update_run))

        for live_path, content in self.originals.items():
            self.assertEqual((test_run / "tree" / live_path.relative_to(self.stack)).read_text(), content)
        self.assertFalse((test_variants / f"{VERSION}-slurm.lua").exists())
        self.assertEqual(len(list(test_variants.glob(".*.bak"))), 6)
        self.assert_originals()

    def test_replace_in_test_rejects_live_stack_as_target(self):
        result = self.invoke("--replace-in-test", str(self.stack), success=False)
        self.assertIn("must name an earlier run below", result.stderr)
        self.assert_originals()

    def test_restore_refuses_post_deployment_edits(self):
        self.invoke("--apply-live")
        run = self.run_directory()
        edited = self.variants / f"{VERSION}-mpi.lua"
        edited.write_text("-- someone changed this after deployment\n")
        result = self.invoke("--apply-live", "--restore", str(run), success=False)
        self.assertIn("Module changed since deployment", result.stderr)
        self.assertEqual(edited.read_text(), "-- someone changed this after deployment\n")
        self.assertTrue((self.variants / f"{VERSION}-slurm.lua").exists())

    def test_restore_accepts_a_partially_published_transaction(self):
        self.invoke("--apply-live")
        run = self.run_directory()
        # Model interruption after some, but not all, atomic renames.
        original = self.variants / f"{VERSION}-mpi.lua"
        original.write_text(self.originals[original])
        original.chmod(0o640)
        (self.variants / f"{VERSION}-slurm.lua").unlink()
        (run / "deployment-state").write_text("deploying\n")
        self.invoke("--apply-live", "--restore", str(run))
        self.assert_originals()

    def test_restore_checks_all_backups_before_changing_any_file(self):
        self.invoke("--apply-live")
        run = self.run_directory()
        backup = next(self.variants.glob(f".{VERSION}-mpi.lua.*.bak"))
        backup.write_text("-- corrupted backup\n")
        before = {path: path.read_bytes() for path in self.variants.glob("*.lua")}
        result = self.invoke("--apply-live", "--restore", str(run), success=False)
        self.assertIn("Missing or changed backup", result.stderr)
        self.assertEqual(before, {path: path.read_bytes() for path in self.variants.glob("*.lua")})

    def test_failed_publication_rolls_back(self):
        tools = self.root / "tools"
        tools.mkdir()
        fail_once = self.root / "failed-once"
        real_mv = shutil.which("mv")
        wrapper = tools / "mv"
        wrapper.write_text(
            "#!/bin/bash\n"
            f'if [ "${{@: -1}}" = "{self.variants}/{VERSION}-mpi.lua" ] && '
            f'[ ! -e "{fail_once}" ]; then\n'
            f'  touch "{fail_once}"\n  exit 1\nfi\n'
            f'exec "{real_mv}" "$@"\n'
        )
        wrapper.chmod(0o755)
        self.environment["PATH"] = str(tools) + os.pathsep + self.environment["PATH"]
        self.invoke("--apply-live", success=False)
        self.assertTrue(fail_once.exists())
        self.assert_originals()
        self.assertEqual((self.run_directory() / "deployment-state").read_text().strip(), "restored")
        for directory in (self.source, self.variants):
            self.assertFalse(list(directory.glob(".singularity-update.*")))

    def test_silent_spack_render_failure_does_not_publish(self):
        self.environment["TEST_NO_RENDER"] = "1"
        self.invoke("--apply-live", success=False)
        self.assert_originals()
        self.assertFalse(list(self.variants.glob(".*.bak")))

    def test_missing_installed_version_does_not_publish(self):
        self.invoke("--apply-live", version="9.9.9", success=False)
        self.assert_originals()

    def test_live_symlink_is_rejected(self):
        target = self.variants / f"{VERSION}-mpi.lua"
        target.unlink()
        target.symlink_to(self.unselected)
        self.invoke("--apply-live", success=False)
        self.assertTrue(target.is_symlink())
        self.assertEqual(self.unselected.read_text(), "-- keep this other version\n")

    def test_restore_requires_explicit_live_flag(self):
        result = self.invoke("--restore", str(self.root), success=False)
        self.assertIn("--restore requires --apply-live", result.stderr)
        self.assert_originals()

    def test_staging_prefix_cannot_be_a_live_directory(self):
        self.invoke("--prefix", str(self.stack / "staging"), success=False)
        self.assert_originals()
        self.assertFalse((self.stack / "staging").exists())


if __name__ == "__main__":
    unittest.main()
