"""Run through spack python -m unittest discover -s scripts/install_manifest/tests."""

from contextlib import ExitStack
import copy
from pathlib import Path
import json
import io
import os
import sys
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
try:
    import spack.config
    import spack.environment as ev
    import spack.modules.lmod
    import spack.paths
    import spack.repo
    import spack.spec
    import spack.store
except ImportError:
    spack = None


@unittest.skipIf(spack is None, "Run through Spack to exercise native APIs")
class SpackInventoryTests(unittest.TestCase):
    def setUp(self):
        from install_manifest import spack_adapter
        self.adapter = spack_adapter
        self.contexts = ExitStack()
        self.addCleanup(self.contexts.close)
        self.root = Path(self.contexts.enter_context(tempfile.TemporaryDirectory()))
        self.contexts.enter_context(patch.dict(os.environ, {"module_cat_list": "libraries"}))
        mock_repo = Path(spack.paths.prefix) / "var/spack/test_repos/spack_repo/builtin_mock"
        self.contexts.enter_context(spack.repo.use_repositories(str(mock_repo)))
        self.contexts.enter_context(spack.store.use_store(self.root / "store"))
        spack.modules.lmod.configuration_registry.clear()
        self.contexts.enter_context(spack.config.override("modules", {
            "default": {
                "roots": {"lmod": str(self.root / "modules")},
                "lmod": {"hierarchy": [], "core_compilers": ["gcc@13.3.1"],
                         "hide_implicits": True, "hash_length": 0,
                         "all": {"autoload": "direct", "environment": {
                             "set": {"PAWSEY_{name}_HOME": "{prefix}"}}},
                         "projections": {"all": "libraries/{name}/{version}"}},
            }}))

    def spec(self, name="libelf", version="0.8.13", letter="a", dependencies=()):
        node = {"name": name, "version": version, "namespace": "builtin_mock",
                "arch": {"platform": "linux", "platform_os": "rocky9", "target": "neoverse_v2"},
                "compiler": {"name": "gcc", "version": "13.3.1"}, "parameters": {},
                "hash": letter * 32, "dependencies": [
                    {"name": spec.name, "hash": spec.dag_hash(),
                     "parameters": {"deptypes": kinds, "virtuals": []}}
                    for spec, kinds in dependencies]}
        nodes = [node]
        for dependency, _ in dependencies:
            nodes.extend(dependency.to_dict()["spec"]["nodes"])
        return spack.spec.Spec.from_dict({"spec": {"_meta": {"version": 4}, "nodes": nodes}})

    def install(self, spec):
        spack.store.STORE.layout.create_install_directory(spec)
        spack.store.STORE.db.add(spec)

    def environment(self, name, *roots):
        environment = ev.create_in_dir(str(self.root / name), with_view=False)
        for spec in roots:
            abstract = spack.spec.Spec(spec.name + "@" + str(spec.version))
            environment.add(abstract)
            environment._add_concrete_spec(abstract, spec)
        environment.write(regenerate=False)
        return self.root / name


    def publish(self, paths, categories):
        return self.adapter.publish(*self.adapter.collect(paths), categories, self.root)

    def cleanup_arguments(self, *roots, environments=("bootstrap",)):
        from install_manifest import MANIFEST_FILE, SCHEMA_VERSION, atomic_write
        sources, packages = self.publish([self.environment(name, *roots) for name in environments],
                                         ["libraries"])
        output = self.root / "installation_metadata" / MANIFEST_FILE
        atomic_write(output, {
            "schema_version": SCHEMA_VERSION, "status": "complete", "system": "ella",
            "install_prefix": str(self.root), "sources": sources, "packages": packages,
        })
        return ["cleanup", "--manifest", str(output)], output

    def test_cleanup_candidates_are_local_managed_hashes_inside_the_prefix(self):
        keep, obsolete = self.spec(), self.spec(letter="b")
        upstream = self.spec(version="0.8.12", letter="c")
        outside = self.spec(name="libdwarf", version="20130729", letter="d")
        external = self.spec(name="cmake", version="3.0", letter="e")
        escaped = self.spec(version="0.8.11", letter="f")
        local_root = self.root / "scoped-store"
        prefix = local_root / "managed"
        upstream_root = prefix / "upstream"
        with spack.store.use_store(upstream_root):
            self.install(upstream)
        with spack.config.override("upstreams", {"test": {"install_tree": str(upstream_root)}}):
            with spack.store.use_store(local_root, extra_data={"projections": {
                    "libelf": "managed/{name}-{version}-{hash}",
                    "all": "managed-other/{name}-{version}-{hash}"}}):
                for spec in (keep, obsolete, outside, escaped):
                    self.install(spec)
                external.external_path = str(prefix / "external")
                Path(external.external_path).mkdir()
                spack.store.STORE.db.add(external)
                escaped_prefix = Path(escaped.prefix)
                escaped_destination = self.root / "escaped-package"
                escaped_prefix.rename(escaped_destination)
                escaped_prefix.symlink_to(escaped_destination, target_is_directory=True)
                manifest = {"packages": {keep.dag_hash(): {"prefix": str(keep.prefix)}}}
                candidates = self.adapter.cleanup_candidates(manifest, prefix)
                self.assertEqual([spec.dag_hash() for spec in candidates], [obsolete.dag_hash()])

    def test_cleanup_rejects_an_installation_layout_changed_since_installation(self):
        obsolete = self.spec()
        self.install(obsolete)
        spack.store.STORE.layout.projections = {"all": "changed/{name}-{version}-{hash}"}
        with self.assertRaisesRegex(ValueError, "layout has changed"):
            self.adapter.cleanup_candidates({"packages": {}}, self.root)
        self.assertTrue(Path(obsolete.prefix).is_dir())

    def test_cleanup_rejects_prefixes_containing_a_retained_external_installation(self):
        obsolete = self.spec()
        self.install(obsolete)
        manifest = {"packages": {"b" * 32: {
            "prefix": str(Path(obsolete.prefix) / "bundled-library")}}}
        with self.assertRaisesRegex(ValueError, "overlaps a retained prefix"):
            self.adapter.cleanup_candidates(manifest, self.root)
        self.assertTrue(Path(obsolete.prefix).is_dir())

    def test_cleanup_ignores_retained_prefixes_outside_the_deployment(self):
        obsolete = self.spec()
        self.install(obsolete)
        for external in (False, True):
            for retained in (Path(self.root.anchor), self.root.parent,
                             self.root.with_name(self.root.name + "-other")):
                with self.subTest(external=external, retained=retained):
                    manifest = {"packages": {"b" * 32: {
                        "prefix": str(retained), "external": external}}}
                    candidates = self.adapter.cleanup_candidates(manifest, self.root)
                    self.assertEqual([spec.dag_hash() for spec in candidates], [obsolete.dag_hash()])

    def test_cleanup_still_rejects_overlaps_within_the_deployment(self):
        obsolete = self.spec()
        self.install(obsolete)
        path = Path(obsolete.prefix)
        for external in (False, True):
            for retained in (self.root, path.parent, path, path / "bundled-library"):
                with self.subTest(external=external, retained=retained):
                    manifest = {"packages": {"b" * 32: {
                        "prefix": str(retained), "external": external}}}
                    with self.assertRaisesRegex(ValueError, "overlaps a retained prefix") as error:
                        self.adapter.cleanup_candidates(manifest, self.root)
                    self.assertIn(str(retained), str(error.exception))
        self.assertTrue(path.is_dir())

    def test_cleanup_does_not_select_the_deployment_prefix_itself(self):
        obsolete = self.spec()
        self.install(obsolete)
        candidates = self.adapter.cleanup_candidates({"packages": {}}, obsolete.prefix)
        self.assertEqual(candidates, [])
        self.assertTrue(Path(obsolete.prefix).is_dir())

    def test_cleanup_apply_preserves_a_system_external_at_the_filesystem_root(self):
        from install_manifest.cli import main
        external = self.spec(name="glibc", version="2.33", letter="c")
        external.external_path = self.root.anchor
        spack.store.STORE.db.add(external)
        keep = self.spec(dependencies=[(external, ["link", "run"])])
        obsolete = self.spec(version="0.8.12", letter="b")
        self.install(keep)
        self.install(obsolete)
        arguments, output = self.cleanup_arguments(keep)
        original = output.read_bytes()
        self.assertEqual(main([*arguments, "--apply"]), 0)
        self.assertEqual({spec.dag_hash() for spec in spack.store.STORE.db.query_local()},
                         {keep.dag_hash(), external.dag_hash()})
        self.assertTrue(Path(keep.prefix).is_dir())
        self.assertFalse(Path(obsolete.prefix).exists())
        self.assertEqual(output.read_bytes(), original)

    def test_cleanup_preview_changes_neither_installations_nor_manifest(self):
        from install_manifest.cli import main
        keep, obsolete = self.spec(), self.spec(version="0.8.12", letter="b")
        self.install(keep)
        self.install(obsolete)
        arguments, output = self.cleanup_arguments(keep)
        original = output.read_bytes()
        captured = io.StringIO()
        with redirect_stdout(captured):
            self.assertEqual(main(arguments), 0)
        self.assertIn("/" + obsolete.dag_hash(), captured.getvalue())
        self.assertIn(str(obsolete.prefix), captured.getvalue())
        self.assertNotIn("/" + keep.dag_hash(), captured.getvalue())
        self.assertTrue(Path(obsolete.prefix).is_dir())
        self.assertEqual(output.read_bytes(), original)
        self.assertEqual({spec.dag_hash() for spec in spack.store.STORE.db.query_local()},
                         {keep.dag_hash(), obsolete.dag_hash()})

    def test_cleanup_apply_uninstalls_obsolete_dependents_before_dependencies(self):
        from install_manifest import validate
        from install_manifest.cli import main
        keep = self.spec()
        dependency = self.spec(name="cmake", version="3.0", letter="b")
        obsolete = self.spec(name="libdwarf", version="20130729", letter="c",
                             dependencies=[(dependency, ["link", "run"])])
        for spec in (keep, dependency, obsolete):
            self.install(spec)
        arguments, output = self.cleanup_arguments(keep)
        self.assertEqual(main([*arguments, "--apply"]), 0)
        self.assertEqual([spec.dag_hash() for spec in spack.store.STORE.db.query_local()],
                         [keep.dag_hash()])
        self.assertTrue(Path(keep.prefix).is_dir())
        for spec in (dependency, obsolete):
            self.assertFalse(Path(spec.prefix).exists())
        validate(json.loads(output.read_text()), "ella", self.root, ["bootstrap"])

    def test_cleanup_apply_with_no_candidates_does_not_invoke_uninstall(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, _ = self.cleanup_arguments(keep)
        with patch.object(self.adapter, "uninstall") as uninstall:
            self.assertEqual(main([*arguments, "--apply"]), 0)
            uninstall.assert_not_called()

    def test_cleanup_native_uninstall_refuses_to_break_a_retained_dependent(self):
        dependency = self.spec(letter="b")
        independent = self.spec(name="cmake", version="3.0", letter="c")
        retained = self.spec(name="libdwarf", version="20130729",
                             dependencies=[(dependency, ["link", "run"])])
        self.install(dependency)
        self.install(independent)
        self.install(retained)
        with self.assertRaises(ValueError):
            self.adapter.uninstall([independent, dependency])
        self.assertEqual({spec.dag_hash() for spec in spack.store.STORE.db.query_local()},
                         {dependency.dag_hash(), independent.dag_hash(), retained.dag_hash()})
        self.assertTrue(Path(dependency.prefix).is_dir())
        self.assertTrue(Path(independent.prefix).is_dir())
        self.assertTrue(Path(retained.prefix).is_dir())

    def test_cleanup_infers_sources_but_checks_explicit_environment_assertions(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, _ = self.cleanup_arguments(keep, environments=("bootstrap", "application"))
        with patch.object(self.adapter, "uninstall") as uninstall:
            self.assertEqual(main(arguments), 0)
            for environments in (["other"], ["bootstrap"], ["bootstrap", "missing"]):
                with self.subTest(environments=environments):
                    selected = [item for name in environments for item in ("--environment", name)]
                    self.assertEqual(main([*arguments, *selected, "--apply"]), 1)
            uninstall.assert_not_called()

    def test_cleanup_uses_manifest_identity_instead_of_ambient_settings(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, _ = self.cleanup_arguments(keep)
        with patch.dict(os.environ, {"SYSTEM": "another-system",
                                     "INSTALL_PREFIX": str(self.root / "another-release")}):
            self.assertEqual(main(arguments), 0)

    def test_cleanup_checks_explicit_system_and_prefix_assertions(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, _ = self.cleanup_arguments(keep)
        with patch.object(self.adapter, "uninstall") as uninstall:
            self.assertEqual(main([*arguments, "--system", "setonix-q", "--apply"]), 1)
            self.assertEqual(main([*arguments, "--install-prefix", str(self.root / "other"),
                                   "--apply"]), 1)
            uninstall.assert_not_called()

    def test_cleanup_rejects_a_store_outside_the_manifest_installation(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, _ = self.cleanup_arguments(keep)
        with tempfile.TemporaryDirectory() as other:
            with spack.store.use_store(Path(other) / "store"):
                with patch.object(self.adapter, "uninstall") as uninstall:
                    self.assertEqual(main([*arguments, "--apply"]), 1)
                    uninstall.assert_not_called()
        self.assertTrue(Path(keep.prefix).is_dir())

    def test_cleanup_rejects_stale_or_different_installation_manifest(self):
        from install_manifest.cli import main
        keep = self.spec()
        self.install(keep)
        arguments, output = self.cleanup_arguments(keep)
        with patch.object(self.adapter, "uninstall") as uninstall:
            source = self.root / "bootstrap/spack.lock"
            original = source.read_bytes()
            source.write_text("{}\n")
            self.assertEqual(main([*arguments, "--apply"]), 1)
            source.write_bytes(original)
            manifest = json.loads(output.read_text())
            manifest["install_prefix"] = str(self.root / "different-release")
            output.write_text(json.dumps(manifest))
            self.assertEqual(main([*arguments, "--install-prefix", str(self.root), "--apply"]), 1)
            uninstall.assert_not_called()

    def test_cleanup_preserves_current_module_when_an_obsolete_projection_matches(self):
        from install_manifest.cli import main
        keep = self.spec(name="mpich", version="3.0.4")
        obsolete = self.spec(name="mpich", version="3.0.4", letter="b")
        self.install(keep)
        self.install(obsolete)
        spack.store.STORE.db.mark(obsolete, "explicit", True)
        configuration = copy.deepcopy(spack.config.get("modules"))
        configuration["default"]["enable"] = ["lmod"]
        configuration["default"]["lmod"]["hierarchy"] = ["mpi"]
        with spack.config.override("modules", configuration):
            arguments, output = self.cleanup_arguments(keep)
            manifest = json.loads(output.read_text())
            module = Path(manifest["packages"][keep.dag_hash()]["module_path"])
            _, obsolete_metadata = self.adapter.module_metadata(obsolete, False, ["libraries"])
            self.assertEqual(obsolete_metadata["module_path"], str(module))
            original = module.read_text()
            self.assertEqual(main([*arguments, "--apply"]), 0)
            self.assertEqual(module.read_text(), original)
            self.assertTrue(Path(keep.prefix).is_dir())
            self.assertFalse(Path(obsolete.prefix).exists())

    def test_shared_hash_is_published_once_with_both_origins(self):
        spec = self.spec()
        self.install(spec)
        first = self.environment("bootstrap", spec)
        second = self.environment("applications", spec)
        sources, packages = self.publish([first, second], ["libraries"])
        self.assertEqual(set(packages), {spec.dag_hash()})
        package = packages[spec.dag_hash()]
        self.assertEqual(set(package["sources"]), {"bootstrap", "applications"})
        self.assertTrue(package["public"])
        self.assertFalse(package["external"])
        self.assertFalse(package["upstream"])
        self.assertEqual(set(sources), {"bootstrap", "applications"})
        for source in sources.values():
            self.assertEqual(source["installed_hashes"], [spec.dag_hash()])
            self.assertNotIn("_hashes", source)
        self.assertTrue(Path(package["module_path"]).is_file())
        self.assertIn('setenv("PAWSEY_LIBELF_HOME",',
                      Path(package["module_path"]).read_text())

    def test_distinct_hashes_with_same_projection_are_rejected(self):
        first, second = self.spec(), self.spec(letter="b")
        paths = [self.environment("one", first), self.environment("two", second)]
        specs, public, _ = self.adapter.collect(paths)
        with self.assertRaisesRegex(ValueError, "module path clash"):
            self.adapter.check_modules(specs, public, ["libraries"])

    def test_fixed_install_prefix_collision_is_rejected(self):
        with spack.store.use_store(self.root / "fixed", extra_data={
                "projections": {"all": "{name}-{version}"}}):
            first, second = self.spec(), self.spec(letter="b")
            self.install(first)
            with self.assertRaisesRegex(ValueError, "Installation prefix clash"):
                self.adapter.check_prefixes({second.dag_hash(): second})

    def test_missing_public_root_is_rejected(self):
        spec = self.spec()
        path = self.environment("missing", spec)
        specs, public, _ = self.adapter.collect([path])
        with self.assertRaisesRegex(ValueError, "not installed"):
            self.adapter.installed_specs(specs, public)

    def test_unconcretized_addition_is_rejected(self):
        path = self.environment("incomplete", self.spec())
        environment = ev.Environment(str(path))
        environment.add("libdwarf")
        environment.write(regenerate=False)
        with self.assertRaisesRegex(ValueError, "not completely concretized"):
            self.adapter.read_environment(path)

    def test_changed_variant_with_same_root_count_is_rejected(self):
        path = self.environment("variant", self.spec())
        manifest = path / "spack.yaml"
        manifest.write_text(manifest.read_text().replace("libelf@0.8.13", "libelf@0.8.13 +debug"))
        with self.assertRaisesRegex(ValueError, "not completely concretized"):
            self.adapter.read_environment(path)

    def test_compilerless_binary_root_metadata(self):
        spec = spack.spec.Spec.from_dict({"spec": {"_meta": {"version": 5}, "nodes": [{
            "name": "cmake", "version": "3.0", "namespace": "builtin_mock",
            "arch": {"platform": "linux", "platform_os": "rocky9", "target": "neoverse_v2"},
            "parameters": {}, "hash": "d" * 32}]}})
        _, entry = self.adapter.module_metadata(spec, True, ["libraries"])
        self.assertIsNone(entry["compiler"])

    def test_missing_build_dependency_does_not_block_publication(self):
        runtime = self.spec(letter="b")
        build = self.spec(name="cmake", version="3.0", letter="c")
        root = self.spec(name="libdwarf", version="20130729", dependencies=[
            (runtime, ["link", "run"]), (build, ["build"])])
        self.install(runtime)
        self.install(root)
        path = self.environment("cache", root)
        sources, packages = self.publish([path], ["libraries"])
        self.assertEqual(set(packages), {root.dag_hash(), runtime.dag_hash()})
        self.assertEqual(sources["cache"]["installed_hashes"], sorted(packages))
        self.assertTrue(packages[root.dag_hash()]["public"])
        self.assertFalse(packages[runtime.dag_hash()]["public"])
        self.assertEqual([entry["hash"] for entry in packages[root.dag_hash()]["autoloads"]],
                         [runtime.dag_hash()])

    def test_inventory_includes_installed_build_and_hidden_non_autoload_dependencies(self):
        runtime = self.spec(letter="b")
        build = self.spec(name="cmake", version="3.0", letter="c")
        unrelated = self.spec(name="libelf", version="0.8.12", letter="d")
        root = self.spec(name="libdwarf", version="20130729", dependencies=[
            (runtime, ["link", "run"]), (build, ["build"])])
        for spec in (runtime, build, unrelated, root):
            self.install(spec)
        path = self.environment("complete", root)
        configuration = copy.deepcopy(spack.config.get("modules"))
        configuration["default"]["lmod"]["all"]["autoload"] = "none"
        with spack.config.override("modules", configuration):
            sources, packages = self.publish([path], ["libraries"])
        self.assertEqual(set(packages), {spec.dag_hash() for spec in (root, runtime, build)})
        self.assertEqual(sources["complete"]["installed_hashes"], sorted(packages))
        self.assertEqual(packages[root.dag_hash()]["autoloads"], [])
        for spec in (runtime, build):
            package = packages[spec.dag_hash()]
            self.assertFalse(package["public"])
            self.assertEqual(package["sources"], ["complete"])
            self.assertTrue(Path(package["module_path"]).is_file())
            modulerc = Path(package["module_path"]).parent / ".modulerc.lua"
            self.assertIn('hide_version("' + package["module_name"] + '")',
                          modulerc.read_text())

    def test_shared_dependency_retains_each_environment_membership(self):
        dependency = self.spec(letter="b")
        first = self.spec(name="libdwarf", version="20130729",
                          dependencies=[(dependency, ["link", "run"])])
        second = self.spec(name="libdwarf", version="20130728", letter="c",
                           dependencies=[(dependency, ["link", "run"])])
        for spec in (dependency, first, second):
            self.install(spec)
        paths = [self.environment("bootstrap", first), self.environment("applications", second)]
        sources, packages = self.publish(paths, ["libraries"])
        self.assertEqual(set(packages[dependency.dag_hash()]["sources"]),
                         {"bootstrap", "applications"})
        self.assertFalse(packages[dependency.dag_hash()]["public"])
        self.assertEqual(sources["bootstrap"]["installed_hashes"],
                         sorted([first.dag_hash(), dependency.dag_hash()]))
        self.assertEqual(sources["applications"]["installed_hashes"],
                         sorted([second.dag_hash(), dependency.dag_hash()]))

    def test_inventory_includes_external_and_upstream_members(self):
        upstream = self.spec(letter="b")
        upstream_store = self.root / "upstream"
        with spack.store.use_store(upstream_store):
            self.install(upstream)
            upstream_prefix = str(upstream.prefix)
        external = self.spec(name="cmake", version="3.0", letter="c")
        external.external_path = str(self.root / "external")
        Path(external.external_path).mkdir()
        root = self.spec(name="libdwarf", version="20130729", dependencies=[
            (upstream, ["link", "run"]), (external, ["build"])])
        with spack.config.override("upstreams", {"test": {"install_tree": str(upstream_store)}}):
            with spack.store.use_store(self.root / "downstream"):
                spack.store.STORE.db.add(external)
                self.install(root)
                path = self.environment("complete", root)
                sources, packages = self.publish([path], ["libraries"])
                self.assertIn('"libraries/' + packages[upstream.dag_hash()]["module_name"] + '"',
                              Path(packages[root.dag_hash()]["module_path"]).read_text())
                public_path = self.environment("public-library", upstream)
                _, promoted = self.publish([path, public_path], ["libraries"])
                self.assertTrue(promoted[upstream.dag_hash()]["public"])
                self.assertEqual(promoted[upstream.dag_hash()]["module_name"], "libelf/0.8.13")
                self.assertIn('"libraries/libelf/0.8.13"',
                              Path(promoted[root.dag_hash()]["module_path"]).read_text())
                _, demoted = self.publish([path], ["libraries"])
                self.assertFalse(demoted[upstream.dag_hash()]["public"])
                self.assertEqual(demoted[upstream.dag_hash()]["module_name"], "libelf/0.8.13-bbbbbbb")
                self.assertIn('"libraries/' + demoted[upstream.dag_hash()]["module_name"] + '"',
                              Path(demoted[root.dag_hash()]["module_path"]).read_text())
                self.assertFalse(spack.store.STORE.db.get_record(upstream).explicit)
        self.assertEqual(set(packages), {spec.dag_hash() for spec in (root, upstream, external)})
        self.assertEqual(sources["complete"]["installed_hashes"], sorted(packages))
        self.assertTrue(packages[upstream.dag_hash()]["upstream"])
        self.assertFalse(packages[upstream.dag_hash()]["external"])
        self.assertEqual(packages[upstream.dag_hash()]["prefix"], upstream_prefix)
        self.assertTrue(packages[external.dag_hash()]["external"])
        self.assertFalse(packages[external.dag_hash()]["upstream"])
        self.assertEqual(packages[external.dag_hash()]["prefix"], external.external_path)
        for spec in (upstream, external):
            self.assertFalse(packages[spec.dag_hash()]["public"])
            self.assertEqual(packages[spec.dag_hash()]["sources"], ["complete"])
            self.assertTrue(Path(demoted[spec.dag_hash()]["module_path"]).is_file())

    def test_inventory_includes_prefixless_external_module(self):
        external = self.spec(name="cmake", version="3.0", letter="b")
        external.external_modules = ["test/cmake"]
        root = self.spec(name="libdwarf", version="20130729",
                         dependencies=[(external, ["build"])])
        spack.store.STORE.db.add(external)
        self.install(root)
        path = self.environment("external", root)
        configuration = copy.deepcopy(spack.config.get("modules"))
        configuration["default"]["lmod"]["exclude"] = ["cmake"]
        with spack.config.override("modules", configuration):
            sources, packages = self.publish([path], ["libraries"])
        self.assertEqual(set(packages), {root.dag_hash(), external.dag_hash()})
        self.assertEqual(sources["external"]["installed_hashes"], sorted(packages))
        package = packages[external.dag_hash()]
        self.assertTrue(package["external"])
        self.assertFalse(package["upstream"])
        self.assertFalse(package["public"])
        self.assertEqual(package["sources"], ["external"])
        self.assertIsNone(package["prefix"])
        for field in ("module_name", "module_path", "scope"):
            self.assertIsNone(package[field])

    def test_missing_runtime_dependency_is_rejected(self):
        dependency = self.spec(letter="b")
        root = self.spec(name="libdwarf", version="20130729",
                         dependencies=[(dependency, ["link", "run"])])
        self.install(root)
        path = self.environment("runtime", root)
        specs, public, _ = self.adapter.collect([path])
        with self.assertRaisesRegex(ValueError, "not installed"):
            self.adapter.installed_specs(specs, public)

    def test_refresh_removes_obsolete_modules(self):
        first, second = self.spec(), self.spec(version="0.8.12", letter="b")
        self.install(first)
        self.install(second)
        _, old_packages = self.publish([self.environment("old", first)], ["libraries"])
        old_path = Path(old_packages[first.dag_hash()]["module_path"])
        _, new_packages = self.publish([self.environment("new", second)], ["libraries"])
        self.assertFalse(old_path.exists())
        self.assertTrue(Path(new_packages[second.dag_hash()]["module_path"]).is_file())

    def test_snapshot_and_cli_publication_use_saved_environment(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE, validate
        spec = self.spec()
        self.install(spec)
        source = self.environment("bootstrap", spec)
        arguments = ["--install-prefix", str(self.root), "--system", "ella",
                     "--manifest", str(self.root / "installation_metadata" / MANIFEST_FILE)]
        self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        snapshot = self.root / "installation_metadata/environments/bootstrap"
        self.assertTrue((snapshot / "spack.lock").is_file())
        with patch.dict(os.environ, {"module_cat_list": "libraries"}):
            self.assertEqual(main(["publish", *arguments, "--environment", "bootstrap"]), 0)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        manifest = json.loads(output.read_text())
        validate(manifest, "ella", self.root, ["bootstrap"])
        (source / "spack.yaml").write_text("spack: {specs: [different]}\n")
        validate(manifest, "ella", self.root)
        (snapshot / "spack.lock").write_text("{}\n")
        with self.assertRaisesRegex(ValueError, "source has changed"):
            validate(manifest)

    def test_modules_only_publication_preserves_registration_without_allowing_cleanup(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE, validate
        bootstrap, application = self.spec(), self.spec(name="libdwarf", version="20130729", letter="b")
        self.install(bootstrap)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        for name, spec in (("bootstrap", bootstrap), ("application", application)):
            source = self.environment(name, spec)
            self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        modules_only = ["publish", *arguments, "--modules-only", "--environment", "bootstrap"]
        self.assertEqual(main(modules_only), 0)
        pending = json.loads(output.read_text())
        self.assertEqual(pending["status"], "pending")
        self.assertEqual(set(pending["sources"]), {"bootstrap", "application"})
        self.assertEqual(pending["packages"], {})
        validate(pending, "ella", self.root, published=False)
        with self.assertRaisesRegex(ValueError, "not published"):
            validate(pending)
        with patch.object(self.adapter, "uninstall") as uninstall:
            self.assertEqual(main(["cleanup", "--manifest", str(output), "--apply"]), 1)
            uninstall.assert_not_called()
        _, entry = self.adapter.module_metadata(bootstrap, True, ["libraries"])
        self.assertTrue(Path(entry["module_path"]).is_file())
        self.assertEqual(main(["publish", *arguments]), 1)
        self.assertEqual(json.loads(output.read_text())["status"], "pending")
        self.install(application)
        self.assertEqual(main(["publish", *arguments]), 0)
        original = output.read_bytes()
        self.assertEqual(main(modules_only), 0)
        self.assertEqual(json.loads(output.read_text())["status"], "pending")
        self.assertEqual(set(json.loads(output.read_text())["sources"]), {"bootstrap", "application"})
        self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
        self.assertTrue(Path(entry["module_path"]).is_file())

    def test_modules_only_is_rejected_for_other_commands(self):
        from install_manifest.cli import main
        self.assertEqual(main(["validate", "--install-prefix", str(self.root),
                               "--modules-only"]), 1)

    def test_native_exclusion_omits_dependency_autoload(self):
        runtime = self.spec(letter="b")
        root = self.spec(name="libdwarf", version="20130729",
                         dependencies=[(runtime, ["link", "run"])])
        self.install(runtime)
        self.install(root)
        path = self.environment("exclusion", root)
        configuration = copy.deepcopy(spack.config.get("modules"))
        configuration["default"]["lmod"]["exclude"] = ["libelf"]
        with spack.config.override("modules", configuration):
            sources, packages = self.publish([path], ["libraries"])
        self.assertEqual(packages[root.dag_hash()]["autoloads"], [])
        dependency = packages[runtime.dag_hash()]
        self.assertFalse(dependency["public"])
        self.assertEqual(dependency["sources"], ["exclusion"])
        self.assertEqual(dependency["prefix"], str(runtime.prefix))
        for field in ("module_name", "module_path", "scope"):
            self.assertIsNone(dependency[field])
        self.assertEqual(sources["exclusion"]["installed_hashes"], sorted(packages))

    def test_public_dependency_promotion_updates_autoload_identity(self):
        runtime = self.spec(letter="b")
        root = self.spec(name="libdwarf", version="20130729",
                         dependencies=[(runtime, ["link", "run"])])
        self.install(runtime)
        self.install(root)
        paths = [self.environment("application", root), self.environment("public-library", runtime)]
        sources, packages = self.publish(paths, ["libraries"])
        dependency = packages[root.dag_hash()]["autoloads"][0]
        self.assertEqual(dependency["module_path"], packages[runtime.dag_hash()]["module_path"])
        self.assertEqual(dependency["module_name"], "libelf/0.8.13")
        self.assertIn('"libraries/libelf/0.8.13"',
                      Path(packages[root.dag_hash()]["module_path"]).read_text())
        self.assertTrue(packages[runtime.dag_hash()]["public"])
        self.assertEqual(set(packages[runtime.dag_hash()]["sources"]),
                         {"application", "public-library"})
        self.assertEqual(sources["application"]["roots"], [root.dag_hash()])
        self.assertEqual(sources["application"]["installed_hashes"], sorted(packages))
        self.assertEqual(sources["public-library"]["roots"], [runtime.dag_hash()])
        self.assertEqual(sources["public-library"]["installed_hashes"], [runtime.dag_hash()])

    def test_sequential_snapshots_publish_and_republish_the_recorded_environment_set(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE, validate
        bootstrap, application = self.spec(), self.spec(name="libdwarf", version="20130729", letter="b")
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        sources = [self.environment("bootstrap", bootstrap), self.environment("application", application)]
        for index, source in enumerate(sources):
            self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
            pending = json.loads(output.read_text())
            self.assertEqual(pending["status"], "pending")
            self.assertEqual(set(pending["sources"]), {path.name for path in sources[:index + 1]})
            self.assertEqual(pending["packages"], {})
            validate(pending, "ella", self.root, published=False)
        self.assertEqual(main(["snapshot", *arguments, "--source", str(sources[0])]), 0)
        self.assertEqual(set(json.loads(output.read_text())["sources"]), {"bootstrap", "application"})
        for spec in (bootstrap, application):
            self.install(spec)
        self.assertEqual(main(["publish", *arguments]), 0)
        manifest = json.loads(output.read_text())
        validate(manifest, "ella", self.root, ["bootstrap", "application"])
        self.assertEqual(set(manifest["packages"]), {bootstrap.dag_hash(), application.dag_hash()})
        original = output.read_bytes()
        self.assertEqual(main(["publish", *arguments]), 0)
        self.assertEqual(set(json.loads(output.read_text())["sources"]), {"bootstrap", "application"})
        self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
        complete = output.read_bytes()
        self.assertEqual(main(["publish", *arguments, "--environment", "bootstrap"]), 1)
        self.assertEqual(output.read_bytes(), complete)

    def test_resnapshot_replaces_one_environment_and_keeps_previous_publication(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        first = self.spec()
        replacement = self.spec(version="0.8.12", letter="c")
        other = self.spec(name="libdwarf", version="20130729", letter="b")
        for spec in (first, replacement, other):
            self.install(spec)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        source = self.environment("bootstrap", first)
        other_source = self.environment("application", other)
        for path in (source, other_source):
            self.assertEqual(main(["snapshot", *arguments, "--source", str(path)]), 0)
        self.assertEqual(main(["publish", *arguments]), 0)
        original = output.read_bytes()
        environment = ev.Environment(str(source))
        environment.remove("libelf", force=True)
        abstract = spack.spec.Spec("libelf@0.8.12")
        environment.add(abstract)
        environment._add_concrete_spec(abstract, replacement)
        environment.write(regenerate=False)
        self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        pending = json.loads(output.read_text())
        self.assertEqual(pending["status"], "pending")
        self.assertEqual(pending["sources"]["bootstrap"]["roots"], [replacement.dag_hash()])
        self.assertEqual(set(pending["sources"]), {"bootstrap", "application"})
        self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
        self.assertEqual(main(["snapshot", *arguments, "--source", str(other_source)]), 0)
        self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
        self.assertEqual(main(["publish", *arguments]), 0)
        self.assertEqual(set(json.loads(output.read_text())["packages"]),
                         {replacement.dag_hash(), other.dag_hash()})

    def test_invalidate_starts_a_fresh_selection_without_rediscovering_old_snapshots(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        bootstrap = self.spec()
        obsolete = self.spec(name="libdwarf", version="20130729", letter="b")
        for spec in (bootstrap, obsolete):
            self.install(spec)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        source = self.environment("bootstrap", bootstrap)
        for path in (source, self.environment("removed", obsolete)):
            self.assertEqual(main(["snapshot", *arguments, "--source", str(path)]), 0)
        self.assertEqual(main(["publish", *arguments]), 0)
        self.assertEqual(main(["invalidate", *arguments]), 0)
        self.assertFalse(output.exists())
        self.assertTrue((self.root / "installation_metadata/environments/removed/spack.lock").is_file())
        self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        self.assertEqual(main(["publish", *arguments]), 0)
        manifest = json.loads(output.read_text())
        self.assertEqual(set(manifest["sources"]), {"bootstrap"})
        self.assertEqual(set(manifest["packages"]), {bootstrap.dag_hash()})
        self.assertEqual([spec.dag_hash() for spec in self.adapter.cleanup_candidates(manifest, self.root)],
                         [obsolete.dag_hash()])

    def test_publish_refuses_changed_saved_inputs_without_generating_modules(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        spec = self.spec()
        self.install(spec)
        source = self.environment("bootstrap", spec)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        original = output.read_bytes()
        saved = self.root / "installation_metadata/environments/bootstrap/spack.lock"
        saved.write_text("{}\n")
        with patch.object(spack.modules.lmod.LmodModulefileWriter, "write") as write:
            self.assertEqual(main(["publish", *arguments]), 1)
            write.assert_not_called()
        self.assertEqual(output.read_bytes(), original)

    def test_snapshot_refuses_module_clashes_against_previously_registered_environments(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        first, second = self.spec(), self.spec(letter="b")
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        first_source = self.environment("bootstrap", first)
        second_source = self.environment("application", second)
        self.assertEqual(main(["snapshot", *arguments, "--source", str(first_source)]), 0)
        original = output.read_bytes()
        with patch.object(spack.modules.lmod.LmodModulefileWriter, "write") as write:
            self.assertEqual(main(["snapshot", *arguments, "--source", str(second_source)]), 1)
            write.assert_not_called()
        self.assertEqual(output.read_bytes(), original)
        self.assertEqual(set(json.loads(output.read_text())["sources"]), {"bootstrap"})

    def test_failed_snapshot_preserves_intended_selection_and_blocks_publication(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        bootstrap = self.spec()
        application = self.spec(name="libdwarf", version="20130729", letter="b")
        replacement = self.spec(name="libdwarf", version="20130728", letter="c")
        for spec in (bootstrap, application, replacement):
            self.install(spec)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella", "--manifest", str(output)]
        bootstrap_source = self.environment("bootstrap", bootstrap)
        application_source = self.environment("application", application)
        self.assertEqual(main(["snapshot", *arguments, "--source", str(bootstrap_source)]), 0)
        self.assertEqual(main(["publish", *arguments]), 0)
        for spec in (application, replacement):
            with self.subTest(updating_existing=spec is replacement):
                if spec is replacement:
                    environment = ev.Environment(str(application_source))
                    environment.remove("libdwarf", force=True)
                    abstract = spack.spec.Spec("libdwarf@20130728")
                    environment.add(abstract)
                    environment._add_concrete_spec(abstract, replacement)
                    environment.write(regenerate=False)
                original = output.read_bytes()
                with patch.object(self.adapter, "snapshot", side_effect=OSError("simulated clone failure")):
                    self.assertEqual(main(["snapshot", *arguments, "--source", str(application_source)]), 1)
                pending = json.loads(output.read_text())
                self.assertEqual(pending["status"], "pending")
                self.assertEqual(set(pending["sources"]), {"bootstrap", "application"})
                self.assertEqual(pending["sources"]["application"]["roots"], [spec.dag_hash()])
                self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
                with patch.object(spack.modules.lmod.LmodModulefileWriter, "write") as write:
                    self.assertEqual(main(["publish", *arguments]), 1)
                    write.assert_not_called()
                self.assertEqual(main(["snapshot", *arguments, "--source", str(application_source)]), 0)
                self.assertEqual(output.with_suffix(".previous.json").read_bytes(), original)
                self.assertEqual(main(["publish", *arguments]), 0)

    def test_partial_module_write_cannot_publish_inventory(self):
        from install_manifest.cli import main
        from install_manifest import MANIFEST_FILE
        spec = self.spec()
        self.install(spec)
        source = self.environment("bootstrap", spec)
        output = self.root / "installation_metadata" / MANIFEST_FILE
        arguments = ["--install-prefix", str(self.root), "--system", "ella",
                     "--manifest", str(output)]
        self.assertEqual(main(["snapshot", *arguments, "--source", str(source)]), 0)
        with patch.dict(os.environ, {"module_cat_list": "libraries"}):
            self.assertEqual(main(["publish", *arguments, "--environment", "bootstrap"]), 0)
            def partial_write(writer, overwrite=False):
                path = Path(writer.layout.filename)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("-- incomplete module\n")
                raise OSError("simulated write failure")
            with patch.object(spack.modules.lmod.LmodModulefileWriter, "write", partial_write):
                self.assertEqual(main(["publish", *arguments, "--environment", "bootstrap"]), 1)
        self.assertEqual(json.loads(output.read_text())["status"], "pending")
        self.assertTrue(output.with_suffix(".previous.json").exists())


if __name__ == "__main__":
    unittest.main()
