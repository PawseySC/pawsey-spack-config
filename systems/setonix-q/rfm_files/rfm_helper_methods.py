"""Small helpers shared by the Setonix-Q ReFrame checks."""

import json
import os

import yaml


def get_env_vars():
    return {
        'env': os.getenv('SPACK_ENV'),
        'spack_repo_path': os.getenv('PAWSEY_SPACK_CONFIG_REPO'),
        'install_prefix': os.getenv('INSTALL_PREFIX'),
        'system': os.getenv('SYSTEM') or 'setonix-q',
    }


def get_pkg_cmds():
    env = get_env_vars()
    path = os.path.join(
        env['spack_repo_path'], 'systems', env['system'], 'rfm_files',
        'pkg_cmds.yaml'
    )
    with open(path, encoding='utf-8') as stream:
        return yaml.safe_load(stream)


def get_abstract_specs():
    """Return the package specs requested by the active environment."""

    env = get_env_vars()
    path = os.path.join(
        env['spack_repo_path'], 'systems', env['system'], 'environments',
        env['env'], 'spack.yaml'
    )
    with open(path, encoding='utf-8') as stream:
        data = yaml.safe_load(stream)

    definitions = {
        name: values
        for definition in data['spack']['definitions']
        for name, values in definition.items()
    }

    def expand(name, active=None):
        active = set() if active is None else active
        if name in active:
            return []
        active = active | {name}
        result = []
        for value in definitions.get(name, []):
            if isinstance(value, str) and value.startswith('$'):
                result.extend(expand(value[1:], active))
            else:
                result.append(value)
        return result

    specs = []
    for entry in data['spack']['specs']:
        matrix = entry['matrix']
        value = matrix[0][0]
        specs.extend(expand(value[1:]) if value.startswith('$') else [value])
    return sorted(specs)


def get_root_specs():
    """Return the concretized root specs from the active environment lockfile."""

    env = get_env_vars()
    path = os.path.join(
        env['spack_repo_path'], 'systems', env['system'], 'environments',
        env['env'], 'spack.lock'
    )
    with open(path, encoding='utf-8') as stream:
        data = json.load(stream)
    return sorted(f"{root['spec']} {root['hash']}" for root in data['roots'])
