import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOL_PATH = REPO_ROOT / "scripts" / "spack_install_manifest.py"
MODULE_SPEC = importlib.util.spec_from_file_location("spack_install_manifest", TOOL_PATH)
manifest_tool = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(manifest_tool)


APP = "aaaaaaaa"
SHARED = "bbbbbbbb"
LIBRARY = "cccccccc"
RUNTIME = "dddddddd"
SKIPPED = "eeeeeeee"
BUILD_APP = "ffffffff"
BUILD_DEP = "gggggggg"
UNUSED = "hhhhhhhh"


def node(node_hash, name, dependencies=(), build_spec=None):
    result = {
        "name": name,
        "version": "1.0",
        "arch": {"platform": "linux", "platform_os": "test", "target": "x86_64"},
        "compiler": {"name": "gcc", "version": "13.3.0"},
        "namespace": "builtin",
        "parameters": {"build_system": "generic"},
        "dependencies": [
            {
                "name": dependency_name,
                "hash": dependency_hash,
                "parameters": {"deptypes": ["build", "link"], "virtuals": []},
            }
            for dependency_hash, dependency_name in dependencies
        ],
        "hash": node_hash,
    }
    if not result["dependencies"]:
        result.pop("dependencies")
    if build_spec:
        result["build_spec"] = {"name": build_spec[1], "hash": build_spec[0]}
    return result


SHARED_NODE = node(SHARED, "shared", ((RUNTIME, "runtime"),))
LIBRARY_NODE = node(LIBRARY, "library")
RUNTIME_NODE = node(RUNTIME, "runtime")
BUILD_DEP_NODE = node(BUILD_DEP, "old-runtime")
BUILD_APP_NODE = node(BUILD_APP, "old-app", ((BUILD_DEP, "old-runtime"),))


def spec_document(nodes):
    return {"spec": {"_meta": {"version": 4}, "nodes": nodes}}


class SpackInstallManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.base = Path(self.temporary_directory.name)
        self.prefix = self.base / "2026.08"
        self.prefix.mkdir()
        self.metadata = self.prefix / "installation_metadata"

    def invoke(self, *arguments, stdin=""):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr), mock.patch(
            "sys.stdin", io.StringIO(stdin)
        ):
            return_code = manifest_tool.main(list(arguments))
        return return_code, stdout.getvalue(), stderr.getvalue()

    def assert_success(self, *arguments, stdin=""):
        return_code, stdout, stderr = self.invoke(*arguments, stdin=stdin)
        self.assertEqual(0, return_code, stderr)
        return stdout

    def assert_failure(self, *arguments, stdin=""):
        return_code, stdout, stderr = self.invoke(*arguments, stdin=stdin)
        self.assertEqual(1, return_code, stdout)
        self.assertIn("error:", stderr)
        return stderr

    def initialise(self, run_id="test-run"):
        # Keep --metadata-root after the subcommand: the production shell uses
        # this ordering, while the CLI also permits it before the subcommand.
        return self.assert_success(
            "init",
            "--metadata-root",
            str(self.metadata),
            "--system",
            "setonix-q",
            "--date-tag",
            "2026.08",
            "--install-prefix",
            str(self.prefix),
            "--spack-version",
            "0.23.1",
            "--run-id",
            run_id,
        )

    def write_spec(self, filename, nodes):
        path = self.base / filename
        path.write_text(json.dumps(spec_document(nodes)), encoding="utf-8")
        return path

    def reset(self, source_type, source_name):
        self.assert_success(
            "reset-receipt",
            "--metadata-root",
            str(self.metadata),
            "--source-type",
            source_type,
            "--source-name",
            source_name,
        )

    def record(self, source_type, source_name, requested_spec, spec_file, mode="root"):
        self.assert_success(
            "record",
            "--metadata-root",
            str(self.metadata),
            "--source-type",
            source_type,
            "--source-name",
            source_name,
            "--requested-spec",
            requested_spec,
            "--spec-file",
            str(spec_file),
            "--install-mode",
            mode,
        )

    def seal(self, source_type, source_name):
        self.assert_success(
            "seal-receipt",
            "--metadata-root",
            str(self.metadata),
            "--source-type",
            source_type,
            "--source-name",
            source_name,
        )

    def create_candidate(self):
        self.initialise()
        self.reset("standalone", "python")
        self.reset("environment", "numerics")

        standalone_spec = self.write_spec(
            "standalone.json", [SHARED_NODE, RUNTIME_NODE]
        )
        app_spec = self.write_spec(
            "app.json",
            [
                node(
                    APP,
                    "app",
                    ((SHARED, "shared"), (LIBRARY, "library")),
                    (BUILD_APP, "old-app"),
                ),
                SHARED_NODE,
                RUNTIME_NODE,
                LIBRARY_NODE,
                BUILD_APP_NODE,
                BUILD_DEP_NODE,
            ],
        )
        skipped_spec = self.write_spec(
            "skipped.json", [node(SKIPPED, "skipped", ((LIBRARY, "library"),)), LIBRARY_NODE]
        )
        self.record("standalone", "python", "shared@1.0", standalone_spec)
        self.record("environment", "numerics", "app@1.0", app_spec)
        self.record(
            "environment",
            "numerics",
            "skipped@1.0",
            skipped_spec,
            mode="dependencies-only",
        )
        self.seal("standalone", "python")
        self.seal("environment", "numerics")
        candidate = self.metadata / manifest_tool.CANDIDATE_FILE
        self.assert_success(
            "assemble",
            "--metadata-root",
            str(self.metadata),
            "--output",
            str(candidate),
            "--standalone",
            "python",
            "--environment",
            "numerics",
        )
        return candidate

    def annotations(self, hashes):
        rows = []
        for node_hash in hashes:
            prefix = self.prefix / "software" / node_hash
            prefix.mkdir(parents=True)
            module_path = self.prefix / "modules" / f"{node_hash}.lua"
            module_path.parent.mkdir(parents=True, exist_ok=True)
            module_path.write_text(f"-- module for {node_hash}\n", encoding="utf-8")
            rows.append(f"{node_hash}\t{prefix}\ttest/{node_hash}\t{module_path}")
        annotations = self.base / "annotations.tsv"
        annotations.write_text("\n".join(rows) + "\n", encoding="utf-8")
        return annotations

    def test_receipts_assemble_root_wins_and_publish_durable_manifest(self):
        candidate = self.create_candidate()
        candidate_data = json.loads(candidate.read_text(encoding="utf-8"))

        self.assertEqual("candidate", candidate_data["status"])
        self.assertEqual("setonix-q", candidate_data["system"])
        self.assertEqual("2026.08", candidate_data["date_tag"])
        self.assertEqual("0.23.1", candidate_data["spack_version"])
        self.assertEqual([APP, SHARED], candidate_data["public_root_hashes"])
        self.assertEqual([LIBRARY, RUNTIME], candidate_data["dependency_hashes"])
        self.assertEqual([APP, SHARED, LIBRARY, RUNTIME], candidate_data["installed_hashes"])

        # SHARED is an environment dependency but is public because it is a
        # standalone root.  Spliced build provenance and a dependencies-only
        # parent remain inspectable, but are not active module hashes.
        self.assertEqual(
            "public-root", candidate_data["specs"][SHARED]["module"]["role"]
        )
        self.assertFalse(candidate_data["specs"][SKIPPED]["installed"])
        self.assertFalse(candidate_data["specs"][BUILD_APP]["installed"])
        skipped_root = candidate_data["environments"]["numerics"]["roots"][1]
        self.assertEqual(SKIPPED, skipped_root["hash"])
        self.assertFalse(skipped_root["installed"])

        environment_dependencies = self.assert_success(
            "hashes",
            "--metadata-root",
            str(self.metadata),
            "--manifest",
            str(candidate),
            "--role",
            "environment-dependency",
        ).splitlines()
        self.assertEqual([f"/{LIBRARY}", f"/{RUNTIME}"], environment_dependencies)

        # Publishing is fail-closed until every active hash has a real prefix
        # and module file.
        self.assertIn(
            "no existing prefix directory",
            self.assert_failure(
                "publish",
                "--metadata-root",
                str(self.metadata),
                "--manifest",
                str(candidate),
                "--check-paths",
            ),
        )
        annotation_file = self.annotations(candidate_data["installed_hashes"])
        self.assert_success(
            "annotate",
            "--metadata-root",
            str(self.metadata),
            "--manifest",
            str(candidate),
            "--annotations",
            str(annotation_file),
        )
        final_path = self.metadata / "spack_install_manifest.json"
        self.assert_success(
            "publish",
            "--metadata-root",
            str(self.metadata),
            "--manifest",
            str(candidate),
            "--output",
            str(final_path),
            "--check-paths",
        )
        final = json.loads(final_path.read_text(encoding="utf-8"))
        self.assertEqual("complete", final["status"])
        self.assertEqual(
            str(self.prefix / "modules" / f"{APP}.lua"), final["specs"][APP]["module"]["path"]
        )
        self.assertEqual(SHARED, final["specs"][APP]["dependencies"][0]["hash"])

        # These aliases match the ReFrame runner.  An individual expected
        # environment is a required member, not an assertion that it is the
        # only environment in a multi-environment deployment.
        self.assert_success(
            "validate",
            "--metadata-root",
            str(self.metadata),
            "--manifest",
            str(final_path),
            "--require-complete",
            "--system",
            "setonix-q",
            "--install-prefix",
            str(self.prefix),
            "--environment",
            "numerics",
        )

        # Resetting a source within the same run archives the useful prior
        # final and removes it from the well-known path, preventing stale
        # metadata consumption while that source is rebuilt.
        self.reset("environment", "numerics")
        self.assertFalse(final_path.exists())
        archived = self.metadata / "history" / "2026.08" / "test-run-spack_install_manifest.json"
        self.assertTrue(archived.is_file())

        # A subsequent deployment run preserves that history.
        self.initialise(run_id="next-run")
        self.assertFalse(final_path.exists())
        self.assertTrue(archived.is_file())

    def test_unsealed_or_empty_receipts_cannot_be_assembled(self):
        self.initialise()
        self.reset("standalone", "python")
        self.assertIn(
            "not a complete installation",
            self.assert_failure(
                "assemble",
                "--metadata-root",
                str(self.metadata),
                "--standalone",
                "python",
            ),
        )

        concrete = self.write_spec("python-unsealed.json", [SHARED_NODE, RUNTIME_NODE])
        self.record("standalone", "python", "shared@1.0", concrete)
        self.assertIn(
            "not a complete installation",
            self.assert_failure(
                "assemble",
                "--metadata-root",
                str(self.metadata),
                "--standalone",
                "python",
            ),
        )
        self.seal("standalone", "python")
        self.assertIn(
            "not open for recording",
            self.assert_failure(
                "record",
                "--metadata-root",
                str(self.metadata),
                "--source-type",
                "standalone",
                "--source-name",
                "python",
                "--requested-spec",
                "shared@1.0",
                "--spec-file",
                str(concrete),
                "--install-mode",
                "root",
            ),
        )

    def test_assemble_rejects_stale_receipt(self):
        self.initialise(run_id="first")
        self.reset("standalone", "python")
        concrete = self.write_spec("python.json", [SHARED_NODE, RUNTIME_NODE])
        self.record("standalone", "python", "shared@1.0", concrete)
        self.seal("standalone", "python")
        self.initialise(run_id="second")
        error = self.assert_failure(
            "assemble",
            "--metadata-root",
            str(self.metadata),
            "--standalone",
            "python",
        )
        self.assertIn("stale receipt", error)

    def test_store_spec_requires_v4_and_accepts_spliced_build_dag(self):
        self.initialise()
        invalid = self.base / "v3.json"
        invalid.write_text(
            json.dumps({"spec": {"_meta": {"version": 3}, "nodes": [node(APP, "app")]}}),
            encoding="utf-8",
        )
        self.assertIn(
            "version 4",
            self.assert_failure(
                "store-spec",
                "--metadata-root",
                str(self.metadata),
                "--spec-file",
                str(invalid),
            ),
        )
        spliced = self.write_spec(
            "spliced.json",
            [
                node(APP, "app", ((LIBRARY, "library"),), (BUILD_APP, "old-app")),
                LIBRARY_NODE,
                BUILD_APP_NODE,
                BUILD_DEP_NODE,
            ],
        )
        output = self.assert_success(
            "--metadata-root",
            str(self.metadata),
            "store-spec",
            "--spec-file",
            str(spliced),
        )
        self.assertEqual(APP, output.strip())
        self.assertEqual(spliced.read_bytes(), (self.metadata / "concrete_specs" / f"{APP}.json").read_bytes())

    def test_lockfile_roots_and_export_are_machine_safe_and_reachable(self):
        lock_path = self.base / "spack.lock"
        lock = {
            "_meta": {"file-type": "spack-lockfile", "lockfile-version": 5, "specfile-version": 4},
            "spack": {"version": "0.23.1", "type": "release"},
            "roots": [{"hash": APP, "spec": "app@1.0 %gcc"}],
            "concrete_specs": {
                APP: node(
                    APP,
                    "app",
                    ((LIBRARY, "library"),),
                    (BUILD_APP, "old-app"),
                ),
                LIBRARY: LIBRARY_NODE,
                BUILD_APP: BUILD_APP_NODE,
                BUILD_DEP: BUILD_DEP_NODE,
                UNUSED: node(UNUSED, "unused"),
            },
        }
        lock_path.write_text(json.dumps(lock), encoding="utf-8")
        roots = self.assert_success("lock-roots", "--lock-file", str(lock_path))
        self.assertEqual(f"{APP}\tapp@1.0 %gcc\n", roots)

        output = self.base / "exported.json"
        self.assert_success(
            "export-lock-spec",
            "--lock-file",
            str(lock_path),
            "--hash",
            f"/{APP}",
            "--output",
            str(output),
        )
        exported = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(4, exported["spec"]["_meta"]["version"])
        self.assertEqual(
            [APP, LIBRARY, BUILD_APP, BUILD_DEP],
            [entry["hash"] for entry in exported["spec"]["nodes"]],
        )
        self.assertNotIn(UNUSED, [entry["hash"] for entry in exported["spec"]["nodes"]])


if __name__ == "__main__":
    unittest.main()
