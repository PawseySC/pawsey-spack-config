"""Small helpers shared by the Ella ReFrame checks."""

import json
import os
import subprocess
from functools import lru_cache


def get_env_vars():
    return {
        'env': os.getenv('SPACK_ENV'),
        'spack_repo_path': os.getenv('PAWSEY_SPACK_CONFIG_REPO'),
        'install_prefix': os.getenv('INSTALL_PREFIX'),
        'system': os.getenv('SYSTEM') or 'ella',
    }


def get_pkg_cmds():
    import yaml

    env = get_env_vars()
    path = os.path.join(
        env['spack_repo_path'], 'systems', env['system'], 'rfm_files',
        'pkg_cmds.yaml'
    )
    with open(path, encoding='utf-8') as stream:
        return yaml.safe_load(stream)


def get_abstract_specs():
    """Return the package specs requested by the active environment."""
    import yaml

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


@lru_cache(maxsize=None)
def get_installed_modules():
    env = get_env_vars()
    path = os.path.join(env['spack_repo_path'], 'systems', 'ella', 'environments', env['env'])
    return json.loads(subprocess.check_output(
        [os.path.join(env['install_prefix'], 'spack/bin/spack'), '-e', path,
         'python', os.path.abspath(__file__)], text=True
    ))


def get_module_paths():
    return sorted(get_installed_modules())


def get_module_dependencies(module_path):
    return get_installed_modules()[module_path]['dependencies']


def get_library_path(module_path):
    return get_installed_modules()[module_path]['prefix']


if __name__ == '__main__':
    import spack.environment
    import spack.modules

    @lru_cache(maxsize=None)
    def module_path(spec):
        if not spec.installed:
            raise RuntimeError(f'{spec} is not installed')
        path = spack.modules.get_module('lmod', spec, True)
        if not path or not os.path.isfile(path):
            raise RuntimeError(f'Missing module for {spec}: {path}')
        return path

    modules = {
        module_path(root): {
            'prefix': str(root.prefix),
            'dependencies': sorted({
                module_path(dep) for dep in root.traverse(root=False, deptype=('link', 'run'))
                if not dep.external
            }),
        }
        for root in spack.environment.active_environment().concrete_roots()
        if not root.external
    }
    if not modules:
        raise RuntimeError('No installed root modules found in the environment')
    print(json.dumps(modules))
