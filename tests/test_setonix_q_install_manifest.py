import importlib.util
import io
import json
import os
import sys
import tempfile
import types
import unittest
from contextlib import nullcontext
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


tool = load_module(
    'setonix_q_install_manifest',
    ROOT / 'systems' / 'setonix-q' / 'install_manifest.py',
)
rfm = load_module(
    'setonix_q_rfm_install_manifest',
    ROOT / 'systems' / 'setonix-q' / 'rfm_files' / 'install_manifest.py',
)


SHARED = 'a' * 32
APP = 'b' * 32
BUILD = 'c' * 32


def node(node_hash, name, dependencies=()):
    return {
        'name': name,
        'version': '1.0',
        'hash': node_hash,
        'dependencies': [
            {
                'name': dep_name,
                'hash': dep_hash,
                'parameters': {'deptypes': dep_types, 'virtuals': []},
            }
            for dep_hash, dep_name, dep_types in dependencies
        ],
    }


def document(*nodes):
    return {'spec': {'_meta': {'version': 4}, 'nodes': list(nodes)}}


class SetonixQManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.prefix = Path(self.temporary.name) / 'install'
        self.metadata = self.prefix / 'installation_metadata'
        self.prefix.mkdir()
        self.invoke(
            'init', '--metadata-root', str(self.metadata), '--system', 'setonix-q',
            '--date-tag', '2026.08', '--install-prefix', str(self.prefix),
            '--spack-version', '0.23.1', '--run-id', 'test-run',
        )

    def tearDown(self):
        self.temporary.cleanup()

    def invoke(self, *arguments):
        result = tool.main(arguments)
        self.assertEqual(0, result)

    def write_spec(self, name, data):
        path = Path(self.temporary.name) / name
        path.write_text(json.dumps(data), encoding='utf-8')
        return path

    def write_text(self, name, data):
        path = Path(self.temporary.name) / name
        path.write_text(data, encoding='utf-8')
        return path

    def source(self, kind, name, requested, data):
        path = self.write_spec(f'{name}.json', data)
        self.invoke(
            'reset-source', '--metadata-root', str(self.metadata),
            '--kind', kind, '--name', name,
        )
        self.invoke(
            'record-spec', '--metadata-root', str(self.metadata),
            '--kind', kind, '--name', name, '--requested-spec', requested,
            '--spec-file', str(path),
        )
        self.invoke(
            'seal-source', '--metadata-root', str(self.metadata),
            '--kind', kind, '--name', name,
        )

    def test_records_assembles_and_publishes_exact_paths(self):
        shared = node(SHARED, 'shared')
        app = node(
            APP, 'app',
            (
                (SHARED, 'shared', ['link', 'run']),
                (BUILD, 'builder', ['build']),
            ),
        )
        builder = node(BUILD, 'builder')
        self.source('standalone', 'python', 'shared@1.0', document(shared))
        self.source('environment', 'numerics', 'app@1.0', document(app, shared, builder))

        candidate = self.metadata / tool.CANDIDATE_FILE
        plan = self.metadata / tool.PLAN_FILE
        self.invoke(
            'assemble', '--metadata-root', str(self.metadata),
            '--standalone', 'python', '--environment', 'numerics',
            '--output', str(candidate), '--plan', str(plan),
        )
        assembled = json.loads(candidate.read_text(encoding='utf-8'))
        self.assertEqual('root', assembled['specs'][SHARED]['role'])
        self.assertEqual([SHARED], assembled['specs'][APP]['dependencies'])
        self.assertEqual(
            ['hash', 'name', 'version', 'role', 'standalone', 'standalone_root',
             'environment', 'environment_root'],
            plan.read_text(encoding='utf-8').splitlines()[0].split('\t'),
        )
        self.assertIn(
            f'{APP}\tapp\t1.0\troot\t0\t0\t1\t1',
            plan.read_text(encoding='utf-8'),
        )

        annotations = []
        for node_hash, spec in assembled['specs'].items():
            if not spec['installed']:
                continue
            prefix = self.prefix / 'software' / node_hash
            module = self.prefix / 'modules' / f'{node_hash}.lua'
            prefix.mkdir(parents=True)
            module.parent.mkdir(parents=True, exist_ok=True)
            module.write_text('-- module\n', encoding='utf-8')
            annotations.append(f'{node_hash}\t{prefix}\ttest/{node_hash}\t{module}')
        annotation_file = self.write_text('annotations.tsv', '\n'.join(annotations) + '\n')
        final = self.metadata / tool.FINAL_FILE
        self.invoke(
            'publish', '--metadata-root', str(self.metadata),
            '--candidate', str(candidate), '--annotations', str(annotation_file),
            '--output', str(final),
        )
        published = json.loads(final.read_text(encoding='utf-8'))
        self.assertEqual('complete', published['status'])
        self.assertTrue(published['specs'][APP]['module_path'].endswith(f'{APP}.lua'))

        environment = {
            'SYSTEM': 'setonix-q', 'INSTALL_PREFIX': str(self.prefix),
            'SPACK_ENV': 'numerics', 'SPACK_INSTALL_MANIFEST': str(final),
        }
        with mock.patch.dict(os.environ, environment, clear=True):
            rfm.clear_manifest_cache()
            module_path = published['specs'][APP]['module_path']
            self.assertEqual([module_path], rfm.get_module_paths())
            self.assertEqual(
                [published['specs'][SHARED]['module_path']],
                rfm.get_module_dependencies(module_path),
            )
            self.assertEqual(published['specs'][APP]['prefix'], rfm.get_library_path(module_path))

    def test_lists_all_roots_from_a_v5_lockfile(self):
        shared = node(SHARED, 'shared')
        app = node(APP, 'app', ((SHARED, 'shared', ['link']),))
        second = node(BUILD, 'second')
        lock = {
            '_meta': {'lockfile-version': 5, 'specfile-version': 4},
            'roots': [
                {'hash': APP, 'spec': 'app@1.0'},
                {'hash': BUILD, 'spec': 'second@1.0'},
            ],
            'concrete_specs': {APP: app, SHARED: shared, BUILD: second},
        }
        lock_file = self.write_spec('spack.lock', lock)
        output = io.StringIO()
        with redirect_stdout(output):
            self.invoke('lock-roots', '--lock-file', str(lock_file))
        self.assertEqual(['app@1.0', 'second@1.0'], output.getvalue().splitlines())

    def test_annotates_modules_in_one_spack_process(self):
        plan = self.write_text(
            'plan.tsv',
            'hash\tname\tversion\trole\tstandalone\tstandalone_root\t'
            'environment\tenvironment_root\n'
            f'{APP}\tapp\t1.0\troot\t0\t0\t1\t1\n'
            f'{SHARED}\tapp\t1.0\tdependency\t0\t0\t1\t0\n',
        )
        prefixes = {
            APP: self.prefix / 'software' / APP,
            SHARED: self.prefix / 'software' / SHARED,
        }
        for prefix in prefixes.values():
            prefix.mkdir(parents=True)

        class FakeSpec:
            def __init__(self, node_hash):
                self.node_hash = node_hash
                self.prefix = prefixes[node_hash]

            def dag_hash(self):
                return self.node_hash

        records = {
            node_hash: types.SimpleNamespace(installed=True, spec=FakeSpec(node_hash))
            for node_hash in (APP, SHARED)
        }
        marked = []
        database = types.SimpleNamespace(
            query_by_spec_hash=lambda node_hash: (False, records.get(node_hash)),
            write_transaction=lambda: nullcontext(),
            mark=lambda spec, field, value: marked.append(
                (spec.dag_hash(), field, value)
            ),
        )
        fake_store = types.ModuleType('spack.store')
        fake_store.STORE = types.SimpleNamespace(db=database)
        fake_modules = types.ModuleType('spack.modules')
        written = []
        module_root = self.prefix / 'modules'

        class FakeWriter:
            def __init__(self, spec, _module_set, explicit=None):
                suffix = '' if explicit else f'-{spec.dag_hash()[:7]}'
                filename = module_root / f'app-1.0{suffix}.lua'
                self.spec = spec
                self.conf = types.SimpleNamespace(excluded=False)
                self.layout = types.SimpleNamespace(
                    filename=str(filename),
                    use_name=f'app/1.0{suffix}',
                    dirname=lambda: str(module_root),
                )

            def write(self, overwrite=False):
                Path(self.layout.filename).parent.mkdir(parents=True, exist_ok=True)
                Path(self.layout.filename).write_text('-- module\n', encoding='utf-8')
                written.append((self.spec.dag_hash(), self.layout.filename, overwrite))

        generated_indices = []
        fake_modules.module_types = {'lmod': FakeWriter}
        fake_modules.common = types.SimpleNamespace(
            generate_module_index=lambda root, writers: generated_indices.append(
                (root, [writer.spec.dag_hash() for writer in writers])
            )
        )
        fake_spack = types.ModuleType('spack')
        fake_spack.modules = fake_modules
        fake_spack.store = fake_store

        annotations = Path(self.temporary.name) / 'annotations.tsv'
        with mock.patch.dict(
            sys.modules,
            {'spack': fake_spack, 'spack.modules': fake_modules, 'spack.store': fake_store},
        ):
            self.invoke(
                'annotate-modules', '--plan', str(plan), '--output', str(annotations),
                '--progress-every', '1',
            )
        lines = annotations.read_text(encoding='utf-8').splitlines()
        self.assertEqual(2, len(lines))
        self.assertIn(f'{APP}\t{prefixes[APP]}\tapp/1.0\t', lines[0])
        self.assertIn(f'{SHARED}\t{prefixes[SHARED]}\tapp/1.0-{SHARED[:7]}\t', lines[1])
        self.assertNotEqual(lines[0].split('\t')[3], lines[1].split('\t')[3])
        self.assertEqual(
            [(APP, lines[0].split('\t')[3], True),
             (SHARED, lines[1].split('\t')[3], True)],
            written,
        )
        self.assertEqual(
            [(str(self.prefix / 'modules'), [APP, SHARED])], generated_indices
        )
        self.assertEqual(
            [(APP, 'explicit', True), (SHARED, 'explicit', False)], marked
        )


if __name__ == '__main__':
    unittest.main()
