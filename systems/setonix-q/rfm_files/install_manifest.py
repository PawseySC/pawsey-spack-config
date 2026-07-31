"""Read the completed Setonix-Q installation manifest for ReFrame."""

import json
import os
from functools import lru_cache


def get_manifest_path():
    override = os.getenv('SPACK_INSTALL_MANIFEST')
    if override:
        return override
    prefix = os.getenv('INSTALL_PREFIX')
    if not prefix:
        return None
    return os.path.join(
        prefix, 'installation_metadata', 'spack_install_manifest.json'
    )


@lru_cache(maxsize=None)
def _read_manifest(path):
    with open(path, encoding='utf-8') as stream:
        return json.load(stream)


def clear_manifest_cache():
    _read_manifest.cache_clear()


def get_manifest():
    path = get_manifest_path()
    if not path or not os.path.isfile(path):
        return None
    manifest = _read_manifest(path)
    if manifest.get('status') != 'complete':
        return None
    if manifest.get('schema_version') != 1:
        raise ValueError(f'Unsupported installation manifest schema in {path}')
    if manifest.get('system') != (os.getenv('SYSTEM') or 'setonix-q'):
        raise ValueError(f'Installation manifest system does not match SYSTEM: {path}')
    prefix = os.getenv('INSTALL_PREFIX')
    if prefix and os.path.normpath(manifest.get('install_prefix', '')) != os.path.normpath(prefix):
        raise ValueError(f'Installation manifest prefix does not match INSTALL_PREFIX: {path}')
    if not isinstance(manifest.get('sources', {}).get('environments'), dict):
        raise ValueError(f'Installation manifest has no environment sources: {path}')
    if not isinstance(manifest.get('specs'), dict):
        raise ValueError(f'Installation manifest has no specs mapping: {path}')
    return manifest


def installation_manifest_is_complete():
    return get_manifest() is not None


def _environment(manifest):
    name = os.getenv('SPACK_ENV')
    if not name:
        return None
    try:
        return manifest['sources']['environments'][name]
    except KeyError as error:
        raise ValueError(
            f'Installation manifest has no environment {name!r}'
        ) from error


def _installed_roots(manifest):
    environment = _environment(manifest)
    if environment is None:
        return []
    return [root['hash'] for root in environment['roots'] if root.get('installed')]


def _root_for_module(manifest, module_path):
    for root_hash in _installed_roots(manifest):
        if manifest['specs'][root_hash]['module_path'] == module_path:
            return root_hash
    raise ValueError(f'{module_path!r} is not an installed root module')


def get_module_paths():
    manifest = get_manifest()
    if manifest is None:
        return []
    return sorted({
        manifest['specs'][root_hash]['module_path']
        for root_hash in _installed_roots(manifest)
    })


def get_module_dependencies(module_path):
    manifest = get_manifest()
    if manifest is None:
        return []
    root = manifest['specs'][_root_for_module(manifest, module_path)]
    return sorted({
        manifest['specs'][dependency]['module_path']
        for dependency in root['dependencies']
    })


def get_library_path(module_path):
    manifest = get_manifest()
    if manifest is None:
        raise ValueError('A completed installation manifest is required')
    return manifest['specs'][_root_for_module(manifest, module_path)]['prefix']
