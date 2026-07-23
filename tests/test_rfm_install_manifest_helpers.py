import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
HELPERS = {
    'setonix': REPO_ROOT / 'systems/setonix/rfm_files/rfm_helper_methods.py',
    'setonix-q': REPO_ROOT / 'systems/setonix-q/rfm_files/rfm_helper_methods.py',
}


def load_helper(system):
    module_name = f'test_{system.replace("-", "_")}_rfm_helper_methods'
    spec = importlib.util.spec_from_file_location(module_name, HELPERS[system])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class InstallationManifestHelperTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.helpers = {system: load_helper(system) for system in HELPERS}

    def make_files(self, base, system, status='complete', meta_schema=False):
        install_prefix = base / 'install'
        manifest_path = (
            install_prefix /
            'installation_metadata/spack_install_manifest.json'
        )
        manifest_path.parent.mkdir(parents=True)

        root_module = str(install_prefix / 'modules/root/demo/2.0.lua')
        public_dependency_module = str(
            install_prefix / 'modules/public/cmake/4.0.lua'
        )
        hidden_dependency_module = str(
            install_prefix / 'modules/dependencies/zlib/1.3-dephash.lua'
        )
        manifest = {
            'schema_version': 1,
            'status': status,
            'system': system,
            'install_prefix': str(install_prefix),
            'environments': {
                'test_env': {
                    'roots': [
                        {'hash': 'actualhash', 'installed': True},
                        {'hash': 'failedhash', 'installed': False},
                    ],
                },
            },
            'specs': {
                'actualhash': {
                    'prefix': '/actual/software/demo-2.0-actualhash',
                    'dependencies': [
                        {'hash': 'publicdephash'},
                        {'hash': 'hiddendephash'},
                    ],
                    'module': {
                        'path': root_module,
                        'use_name': 'root/demo/2.0',
                    },
                },
                'publicdephash': {
                    'prefix': '/actual/software/cmake-4.0-publicdephash',
                    'dependencies': [],
                    'module': {
                        'path': public_dependency_module,
                        'use_name': 'public/cmake/4.0',
                    },
                },
                'hiddendephash': {
                    'prefix': '/actual/software/zlib-1.3-hiddendephash',
                    'dependencies': [],
                    'module': {
                        'path': hidden_dependency_module,
                        'use_name': 'dependencies/zlib/1.3-dephash',
                    },
                },
            },
        }
        if meta_schema:
            manifest['_meta'] = {'schema_version': manifest.pop('schema_version')}
        manifest_path.write_text(json.dumps(manifest))

        lock_dir = base / f'repo/systems/{system}/environments/test_env'
        lock_dir.mkdir(parents=True)
        (lock_dir / 'spack.lock').write_text(json.dumps({
            'roots': [{'spec': 'demo@1.0', 'hash': 'lockhash'}],
            'concrete_specs': {},
        }))

        return {
            'manifest': manifest,
            'manifest_path': manifest_path,
            'install_prefix': install_prefix,
            'repo': base / 'repo',
            'root_module': root_module,
            'dependency_modules': sorted([
                public_dependency_module,
                hidden_dependency_module,
            ]),
        }

    def helper_environment(self, system, files):
        return mock.patch.dict(os.environ, {
            'SYSTEM': system,
            'SPACK_ENV': 'test_env',
            'INSTALL_PREFIX': str(files['install_prefix']),
            'PAWSEY_SPACK_CONFIG_REPO': str(files['repo']),
        }, clear=True)

    def test_installation_queries_use_actual_manifest_hashes_and_paths(self):
        for system, helper in self.helpers.items():
            with self.subTest(system=system), tempfile.TemporaryDirectory() as tmp:
                files = self.make_files(Path(tmp), system)
                with self.helper_environment(system, files):
                    helper.clear_install_manifest_cache()
                    self.assertEqual(
                        helper.get_root_specs(),
                        ['demo@1.0 lockhash'],
                    )
                    self.assertEqual(
                        helper.get_module_paths(),
                        [files['root_module']],
                    )
                    self.assertEqual(
                        helper.get_module_dependencies(files['root_module']),
                        files['dependency_modules'],
                    )
                    self.assertEqual(
                        helper.get_library_path(files['root_module']),
                        '/actual/software/demo-2.0-actualhash',
                    )

    def test_missing_or_incomplete_manifest_has_no_installation_parameters(self):
        for system, helper in self.helpers.items():
            with self.subTest(system=system), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                files = self.make_files(base, system, status='candidate')
                with self.helper_environment(system, files):
                    helper.clear_install_manifest_cache()
                    self.assertFalse(helper.installation_manifest_is_complete())
                    self.assertEqual(helper.get_module_paths(), [])

                    files['manifest_path'].unlink()
                    helper.clear_install_manifest_cache()
                    self.assertFalse(helper.installation_manifest_is_complete())
                    self.assertEqual(helper.get_module_paths(), [])

    def test_meta_schema_and_manifest_override_are_supported(self):
        for system, helper in self.helpers.items():
            with self.subTest(system=system), tempfile.TemporaryDirectory() as tmp:
                files = self.make_files(Path(tmp), system, meta_schema=True)
                override = Path(tmp) / 'published-manifest.json'
                files['manifest_path'].replace(override)
                with self.helper_environment(system, files), mock.patch.dict(
                    os.environ,
                    {'SPACK_INSTALL_MANIFEST': str(override)},
                ):
                    helper.clear_install_manifest_cache()
                    self.assertTrue(helper.installation_manifest_is_complete())
                    self.assertEqual(
                        helper.get_install_manifest_path(),
                        str(override),
                    )

    def test_complete_manifest_identity_mismatch_fails(self):
        for system, helper in self.helpers.items():
            with self.subTest(system=system), tempfile.TemporaryDirectory() as tmp:
                files = self.make_files(Path(tmp), system)
                files['manifest']['system'] = 'wrong-system'
                files['manifest_path'].write_text(json.dumps(files['manifest']))
                with self.helper_environment(system, files):
                    helper.clear_install_manifest_cache()
                    with self.assertRaisesRegex(ValueError, 'does not match SYSTEM'):
                        helper.get_module_paths()


if __name__ == '__main__':
    unittest.main()
