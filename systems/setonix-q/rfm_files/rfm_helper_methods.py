"""Small helpers shared by the Setonix-Q ReFrame checks."""

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
