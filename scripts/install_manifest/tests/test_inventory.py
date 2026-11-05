import copy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import install_manifest as inventory
from install_manifest.cli import main


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="module inventory ")
        self.addCleanup(self.temporary.cleanup)
        self.prefix = Path(self.temporary.name)
        self.source = self.prefix / "installation_metadata/environments/example"
        self.source.mkdir(parents=True)
        (self.source / "spack.yaml").write_text("spack: {specs: [example]}\n")
        (self.source / "spack.lock").write_text("{}\n")
        self.module = self.prefix / "modules/gcc/13/libraries/example/1.0.lua"
        self.module.parent.mkdir(parents=True)
        self.module.write_text("-- fixture\n")
        self.software = self.prefix / "software/example"
        self.software.mkdir(parents=True)
        self.manifest = {
            "schema_version": 3, "status": "complete", "system": "ella",
            "install_prefix": str(self.prefix),
            "sources": {"example": {"path": str(self.source),
                                    "digest": inventory.source_digest(self.source),
                                    "roots": ["a" * 32], "installed_hashes": ["a" * 32]}},
            "packages": {"a" * 32: {
                "hash": "a" * 32, "name": "example", "version": "1.0",
                "compiler": None, "public": True, "external": False, "upstream": False,
                "sources": ["example"], "scope": str(self.prefix / "modules/gcc/13"),
                "module_name": "example/1.0", "module_path": str(self.module),
                "prefix": str(self.software), "autoloads": [],
            }},
        }
        self.output = self.prefix / "installation_metadata" / inventory.MANIFEST_FILE
        inventory.atomic_write(self.output, self.manifest)
        self.environment = patch.dict(os.environ, {
            "SYSTEM": "ella", "INSTALL_PREFIX": str(self.prefix), "SPACK_ENV": "example",
            "SPACK_INSTALL_MANIFEST": str(self.output),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        inventory.clear_manifest_cache()

    def add_dependency(self, letter, module=True, public=False):
        node_hash = letter * 32
        name = "dependency-" + letter
        software = self.prefix / "software" / name
        software.mkdir()
        module_name = ("" if public else ".") + name + "/1.0" if module else None
        module_path = self.module.parent / (module_name.replace("/", "-") + ".lua") if module else None
        if module_path:
            module_path.write_text("-- hidden dependency\n")
        package = {
            "hash": node_hash, "name": name, "version": "1.0", "compiler": None,
            "public": public, "external": False, "upstream": False,
            "sources": ["example"], "prefix": str(software), "autoloads": [],
            "module_name": module_name,
            "module_path": str(module_path) if module else None,
            "scope": str(self.prefix / "modules/gcc/13") if module else None,
        }
        self.manifest["packages"][node_hash] = package
        self.manifest["sources"]["example"]["installed_hashes"].append(node_hash)
        return package

    def test_source_change_invalidates_cached_reader(self):
        self.assertEqual(inventory.get_module_paths(), [str(self.module)])
        (self.source / "spack.lock").write_text('{"changed": true}\n')
        with self.assertRaisesRegex(ValueError, "source has changed"):
            inventory.get_module_paths()

    def pending_manifest(self):
        pending = copy.deepcopy(self.manifest)
        pending["status"] = "pending"
        pending["packages"] = {}
        pending["sources"]["example"].pop("installed_hashes")
        return pending

    def test_pending_registration_can_be_validated_without_installed_packages(self):
        pending = self.pending_manifest()
        self.assertIs(inventory.validate(pending, "ella", self.prefix, published=False), pending)
        inventory.atomic_write(self.output, pending)
        self.assertEqual(main(["validate", "--install-prefix", str(self.prefix),
                               "--manifest", str(self.output)]), 0)

    def test_pending_registration_is_not_a_published_inventory(self):
        pending = self.pending_manifest()
        with self.assertRaisesRegex(ValueError, "not published"):
            inventory.validate(pending)
        inventory.atomic_write(self.output, pending)
        with self.assertRaisesRegex(ValueError, "not published"):
            inventory.get_module_paths()

    def test_pending_registration_still_rejects_changed_saved_inputs(self):
        pending = self.pending_manifest()
        (self.source / "spack.lock").write_text('{"changed": true}\n')
        with self.assertRaisesRegex(ValueError, "source has changed"):
            inventory.validate(pending, published=False)

    def test_pending_registration_cannot_claim_installed_packages(self):
        pending = self.pending_manifest()
        pending["packages"] = self.manifest["packages"]
        with self.assertRaises(ValueError):
            inventory.validate(pending, published=False)

    def test_requested_environment_must_be_present(self):
        with self.assertRaisesRegex(ValueError, "missing requested environments"):
            inventory.validate(self.manifest, environments=["missing"])

    def test_removed_environment_cannot_survive_in_the_inventory(self):
        self.manifest["sources"]["removed"] = copy.deepcopy(self.manifest["sources"]["example"])
        with self.assertRaisesRegex(ValueError, "outside the requested deployment"):
            inventory.validate(self.manifest, environments=["example"])

    def test_public_module_must_be_an_intended_root(self):
        self.manifest["sources"]["example"]["roots"] = []
        with self.assertRaisesRegex(ValueError, "exactly match intended source roots"):
            inventory.validate(self.manifest)

    def test_inventory_cannot_omit_an_intended_public_root(self):
        self.add_dependency("b")
        self.manifest["sources"]["example"]["roots"].append("b" * 32)
        with self.assertRaisesRegex(ValueError, "exactly match intended source roots"):
            inventory.validate(self.manifest)

    def test_all_installed_packages_are_recorded_but_only_public_roots_are_selected(self):
        hidden = self.add_dependency("b")
        excluded = self.add_dependency("c", module=False)
        excluded["external"] = True
        hidden["upstream"] = True
        inventory.atomic_write(self.output, self.manifest)
        self.assertEqual(set(inventory.get_manifest()["packages"]), {letter * 32 for letter in "abc"})
        self.assertEqual(inventory.get_module_paths(), [str(self.module)])
        self.assertEqual(inventory.get_module_dependencies(str(self.module)), [])

    def test_inventory_cannot_omit_an_installed_dependency(self):
        self.add_dependency("b", module=False)
        del self.manifest["packages"]["b" * 32]
        with self.assertRaisesRegex(ValueError, "exactly match installed source specs"):
            inventory.validate(self.manifest)

    def test_inventory_cannot_include_a_package_outside_the_selected_environments(self):
        self.add_dependency("b")
        self.manifest["sources"]["example"]["installed_hashes"].remove("b" * 32)
        with self.assertRaisesRegex(ValueError, "exactly match installed source specs"):
            inventory.validate(self.manifest)

    def test_package_sources_must_match_installed_environment_membership(self):
        for sources in ([], ["example", "unselected"]):
            with self.subTest(sources=sources):
                self.manifest["packages"]["a" * 32]["sources"] = sources
                with self.assertRaisesRegex(ValueError, "incorrect source membership"):
                    inventory.validate(self.manifest)

    def test_environment_selection_uses_its_public_roots_instead_of_all_memberships(self):
        dependency = self.add_dependency("b", public=True)
        self.manifest["sources"]["application"] = copy.deepcopy(self.manifest["sources"]["example"])
        self.manifest["sources"]["application"]["roots"] = ["b" * 32]
        for package in self.manifest["packages"].values():
            package["sources"].append("application")
        inventory.atomic_write(self.output, self.manifest)
        self.assertEqual(inventory.get_module_paths(), [str(self.module)])
        os.environ["SPACK_ENV"] = "application"
        self.assertEqual(inventory.get_module_paths(), [dependency["module_path"]])
        os.environ.pop("SPACK_ENV")
        self.assertEqual(set(inventory.get_module_paths()), {str(self.module), dependency["module_path"]})

    def test_hidden_and_moduleless_package_prefixes_are_validated(self):
        for module in (True, False):
            with self.subTest(module=module):
                package = self.add_dependency("b" if module else "c", module=module)
                Path(package["prefix"]).rmdir()
                with self.assertRaisesRegex(ValueError, "Missing prefix"):
                    inventory.validate(self.manifest)
                Path(package["prefix"]).mkdir()

    def test_external_package_may_have_no_prefix(self):
        package = self.add_dependency("b", module=False)
        package.update(external=True, prefix=None)
        self.assertIs(inventory.validate(self.manifest), self.manifest)

    def test_managed_package_requires_a_prefix(self):
        self.manifest["packages"]["a" * 32]["prefix"] = None
        with self.assertRaisesRegex(ValueError, "[Pp]refix"):
            inventory.validate(self.manifest)

    def test_hidden_package_modulefile_is_validated(self):
        package = self.add_dependency("b")
        Path(package["module_path"]).unlink()
        with self.assertRaisesRegex(ValueError, "Missing module"):
            inventory.validate(self.manifest)

    def test_public_package_requires_a_module(self):
        package = self.manifest["packages"]["a" * 32]
        package.update(module_name=None, module_path=None, scope=None)
        with self.assertRaisesRegex(ValueError, "Public package has no module"):
            inventory.validate(self.manifest)

    def test_empty_module_path_is_rejected(self):
        self.manifest["packages"]["a" * 32]["module_path"] = ""
        with self.assertRaisesRegex(ValueError, "Incomplete module metadata"):
            inventory.validate(self.manifest)

    def test_missing_inventory_fails_outside_concretization_mode(self):
        self.output.unlink()
        with self.assertRaisesRegex(ValueError, "inventory is required"):
            inventory.get_module_paths()

    def test_concretization_import_explicitly_skips_module_selection(self):
        os.environ["SPACK_INSTALL_MANIFEST"] = str(self.output.parent / ".concretization-only")
        self.assertEqual(inventory.get_module_paths(), [])

    def test_cache_respects_system_identity(self):
        inventory.get_manifest()
        os.environ["SYSTEM"] = "setonix-q"
        with self.assertRaisesRegex(ValueError, "system does not match"):
            inventory.get_manifest()

    def test_source_change_with_preserved_mtime_is_rejected(self):
        inventory.get_manifest()
        lockfile = self.source / "spack.lock"
        stamp = lockfile.stat()
        lockfile.write_text('{"changed": true}\n')
        os.utime(lockfile, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        with self.assertRaisesRegex(ValueError, "source has changed"):
            inventory.get_manifest()

    def test_visible_name_clash_across_categories_is_rejected(self):
        other = copy.deepcopy(self.manifest["packages"]["a" * 32])
        other.update(hash="b" * 32, module_path=str(self.module).replace("libraries", "utilities"))
        self.manifest["sources"]["example"]["roots"].append(other["hash"])
        self.manifest["sources"]["example"]["installed_hashes"].append(other["hash"])
        self.manifest["packages"][other["hash"]] = other
        with self.assertRaisesRegex(ValueError, "conflicting module identities"):
            inventory.validate(self.manifest)

    def run_identity_check(self, loaded, prefix=None):
        commands = inventory.module_identity_commands(str(self.module))
        environment = dict(os.environ, _LMFILES_=loaded,
                           PAWSEY_EXAMPLE_HOME=prefix or str(self.software))
        return subprocess.run(["bash", "-c", "\n".join(commands)], env=environment,
                              text=True, capture_output=True)

    def test_exact_loaded_path_with_spaces_is_accepted(self):
        result = self.run_identity_check(str(self.module))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("manifest module verified: " + "a" * 32, result.stdout)

    def test_same_name_from_wrong_tree_is_rejected(self):
        result = self.run_identity_check(str(self.module).replace("/modules/", "/other-tree/"))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("manifest module verified:", result.stdout)

    def test_expected_module_path_with_wrong_prefix_is_rejected(self):
        result = self.run_identity_check(str(self.module), prefix="/other-installation")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("manifest module verified:", result.stdout)

    def test_module_only_external_checks_exact_loaded_module_path(self):
        self.manifest["packages"]["a" * 32].update(external=True, prefix=None)
        inventory.atomic_write(self.output, self.manifest)
        commands = "\n".join(inventory.module_identity_commands(str(self.module)))
        self.assertIn("_LMFILES_", commands)
        self.assertNotIn("PAWSEY_EXAMPLE_HOME", commands)
        result = self.run_identity_check(str(self.module))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("manifest module verified: " + "a" * 32, result.stdout)
        result = self.run_identity_check(str(self.module).replace("/modules/", "/other-tree/"))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("manifest module verified:", result.stdout)

    def test_missing_autoload_is_rejected_even_without_lua_directive(self):
        dependency = self.add_dependency("b")
        self.manifest["packages"]["a" * 32]["autoloads"] = [
            {key: dependency[key] for key in ("hash", "module_name", "module_path")}]
        inventory.atomic_write(self.output, self.manifest)
        result = self.run_identity_check(str(self.module))
        self.assertNotEqual(result.returncode, 0)
        result = self.run_identity_check(str(self.module) + ":" + dependency["module_path"])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalidate_removes_published_inventory(self):
        self.assertEqual(main(["invalidate", "--install-prefix", str(self.prefix)]), 0)
        self.assertFalse(self.output.exists())
        self.assertTrue(self.output.with_suffix(".previous.json").exists())

    def test_legacy_schema_fails_with_regeneration_instruction(self):
        for version in (1, 2):
            with self.subTest(version=version):
                self.manifest["schema_version"] = version
                with self.assertRaisesRegex(ValueError, "regenerate"):
                    inventory.validate(self.manifest)


if __name__ == "__main__":
    unittest.main()
