# Copyright 2016-2021 Swiss National Supercomputing Centre (CSCS/ETH Zurich)
# ReFrame Project Developers. See the top-level LICENSE file for details.
#
# SPDX-License-Identifier: BSD-3-Clause

import reframe as rfm
from reframe.core.backends import getlauncher
import reframe.utility.sanity as sn
import reframe.utility.udeps as udeps

import re
import os
import sys
import shlex
from pathlib import Path

# Import file with helper methods for processing spack files needed by below tests
curr_dir = os.path.dirname(__file__).replace('\\','/')
parent_dir = os.path.abspath(os.path.join(curr_dir, os.pardir))
sys.path.append(parent_dir)
from rfm_files.rfm_helper_methods import *
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from install_manifest import (
    get_module,
    get_module_name,
    get_expected_autoloads,
    module_identity_commands,
    get_library_path,
    get_module_dependencies,
    get_module_paths,
)

# Dictionary holding commands for every package used in baseline sanity check
pkg_cmds = get_pkg_cmds()


# The shared reader returns no modules in explicit concretization-only mode;
# normal installation checks require a published inventory.
full_mod_paths = get_module_paths()


def module_setup_commands(module_path=None):
    date_tag = os.environ.get('DATE_TAG') or os.environ.get('pawseyenv_version', '2026.08')
    install_prefix = os.environ.get('INSTALL_PREFIX', '${INSTALL_PREFIX}')
    compiler = (get_module(module_path).get('compiler') if module_path else None) or {}
    compiler_module = (
        'nvhpc-nompi/' + compiler['version'] if compiler.get('name') == 'nvhpc'
        else 'gcc/' + os.environ['gcc_version']
    )

    return [
        'module purge',
        'module load pawsey',
        f"module use {shlex.quote(install_prefix + '/staff_modulefiles')}",
        f'module load pawseyenv/{date_tag}',
        f'module load {compiler_module}',
    ]


def get_baseline_cmd(mod_category, base_name):
    return (pkg_cmds.get(mod_category) or {}).get(base_name)


@rfm.simple_test
class concretise_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check that every spec in an environment was concretised successfully'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['ella:compute']
        self.valid_prog_environs = ['gcc']
        self.num_tasks = self.num_tasks_per_node = self.num_cpus_per_task = 1

        # Execution
        self.prerun_cmds = module_setup_commands() + [
            f'module load spack/{os.environ["spack_version"]}'
        ]
        self.executable = 'spack'
        helper = Path(__file__).resolve().parents[3] / 'scripts/reframe_concretization.py'
        metadata = Path(os.getenv('INSTALLATION_METADATA_DIR') or
                        Path(os.environ['INSTALL_PREFIX']) / 'installation_metadata')
        environment = metadata / 'environments' / os.environ['SPACK_ENV']
        self.executable_opts = [shlex.quote(str(value)) for value in (
            '-E', 'python', helper, environment
        )]

        self.tags = {'spack', 'concretization', 'software_stack'}
    
    env = parameter([os.environ['SPACK_ENV']])

    @run_after('setup')
    def configure_ella_step(self):
        # Ella provides pmi2; its default pmix plugin is unavailable.
        self.job.launcher.options += ['--mpi=pmi2']

    @sanity_function
    def assert_concretisation(self):
        return sn.assert_found('Concretization verified:', self.stdout)


@rfm.simple_test
class module_existence_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check for existence of a module during software stack installation'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['ella:shell']
        self.valid_prog_environs = ['gcc']
        self.num_tasks = self.num_tasks_per_node = self.num_cpus_per_task = 1

        # Execution - ls to check the module exists
        self.executable = 'ls'
        self.executable_opts = [shlex.quote(self.mod)]
        # Get dependencies for the module and add ls commands for those
        dependencies = get_module_dependencies(self.mod)
        if len(dependencies) > 0:
            self.postrun_cmds = [f'ls {shlex.quote(d)}' for d in dependencies]

        self.tags = {'spack', 'installation', 'software_stack', get_module(self.mod)['hash']}
    
    # Test parameter - list of full absolute paths for every module in the environment
    mod = parameter(full_mod_paths)

    @sanity_function
    def assert_module_exists(self):
        return sn.assert_not_found('No such file or directory', self.stderr)



@rfm.simple_test
class module_load_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check a module can load properly during software stack installation'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['ella:shell']
        self.valid_prog_environs = ['gcc']
        self.num_tasks = self.num_tasks_per_node = self.num_cpus_per_task = 1

        # Execution
        self.executable = 'module'
        self.name_ver = get_module_name(self.mod)
        self.executable_opts = ['load', shlex.quote(self.name_ver)]

        # module show to check the exact modulefile selected for this test
        self.prerun_cmds += module_setup_commands(self.mod)
        self.prerun_cmds += [f'module show {shlex.quote(self.name_ver)}']
        # Check main module is loaded
        self.postrun_cmds = [f'if module is-loaded {shlex.quote(self.name_ver)} ; then echo "main package is loaded"; fi']

        self.tags = {'spack', 'installation', 'software_stack', get_module(self.mod)['hash']}

    # Test parameter - list of full absolute paths for each module in the environment    
    mod = parameter(full_mod_paths)
    
    # Dependency - this test only runs if the corresponding `module_existence_check` test passes
    @run_after('init')
    def inject_dependencies(self):
        testdep_name = f'module_existence_check_{self.mod}'
        # ReFrame replaces instances of "/", ".", "-", and "+" in test name with "_"
        chars = "/.-+"
        for c in chars:
            testdep_name = testdep_name.replace(c, '_')
        self.depends_on(testdep_name, udeps.by_env)
    
    @run_before('run')
    def check_expected_autoloads(self):
        self.dependency_modules = get_expected_autoloads(self.mod)
        self.postrun_cmds += [
            f'if module is-loaded {shlex.quote(name)}; then echo "dependency is loaded"; fi'
            for name in self.dependency_modules
        ]
        self.postrun_cmds += module_identity_commands(self.mod)

    @sanity_function
    def assert_module_loaded(self):
        return sn.all([
            sn.assert_found("main package is loaded", self.stdout),
            sn.assert_eq(
                sn.count(sn.extractall('dependency is loaded', self.stdout)),
                len(self.dependency_modules),
            ),
            sn.assert_found(re.escape(self.name_ver), self.stderr),
            sn.assert_found(re.escape('manifest module verified: ' + get_module(self.mod)['hash']),
                            self.stdout),
            sn.assert_not_found('Failed', self.stderr),
            sn.assert_not_found('Error', self.stderr),
        ])


@rfm.simple_test
class baseline_sanity_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check that, once the module is loaded, the software shows the most minimal functionality (--help or --version)'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['ella:compute']
        self.valid_prog_environs = ['gcc']
        self.num_tasks = self.num_tasks_per_node = self.num_cpus_per_task = 1

        # Load the module we are testing
        self.name_ver = get_module_name(self.mod)
        self.prerun_cmds += module_setup_commands(self.mod)
        self.prerun_cmds += [f'module load {shlex.quote(self.name_ver)}']
        self.prerun_cmds += module_identity_commands(self.mod)

        # Execution - call executable with `--help` or `--version` option
        self.base_name = self.mod.split('/')[-2] # Extract package/library name from full module path
        self.mod_category = self.mod.split('/')[-3]
        # Prefer a versioned command for projected modules that need one, then
        # fall back to a generic command keyed by package name.
        self.baseline_key = self.name_ver
        self.baseline_cmd = get_baseline_cmd(self.mod_category, self.baseline_key)
        if self.baseline_cmd is None:
            self.baseline_key = self.base_name
            self.baseline_cmd = get_baseline_cmd(self.mod_category, self.baseline_key)
        if self.baseline_cmd is None:
            self.skip_if(
                True,
                'Missing baseline sanity test coverage: '
                f'no command configured in pkg_cmds.yaml for {self.mod}'
            )
            self.baseline_cmd = ['true', '', '']

        self.executable = self.baseline_cmd[0]
        # Set the executable options, which depends on if it's software or library
        if self.executable == 'ldd':
            lib_path = get_library_path(self.mod)
            self.executable_opts = [lib_path + '/' + self.baseline_cmd[1]]
        else:
            self.executable_opts = [self.baseline_cmd[1] + ' 2>&1']
        
        self.tags = {'spack', 'installation', 'software_stack', get_module(self.mod)['hash']}

    @run_after('setup')
    def configure_ella_step(self):
        # Commands explicitly using mpirun launch inside the allocation.
        if self.executable == 'mpirun':
            self.job.launcher = getlauncher('local')()
            return

        # Override the unavailable pmix default for srun-launched checks.
        self.job.launcher.options += ['--mpi=pmi2']

    # Dependency - this test only runs if the corresponding `module_load_check` test passes
    @run_after('init')
    def inject_dependencies(self):
        testdep_name = f'module_load_check_{self.mod}'
        # ReFrame replaces instances of "/" and "." in test name with "_"
        chars = "/.-+"
        for c in chars:
            testdep_name = testdep_name.replace(c, '_')
        self.depends_on(testdep_name, udeps.by_env)

    mod = parameter(full_mod_paths)

    @sanity_function
    def assert_functioning(self):
        # For libraries we check if all libraries are present
        if self.executable == 'ldd':
            return sn.all([sn.assert_found('manifest module verified:', self.stdout),
                           sn.assert_not_found('not found', self.stdout)])
        # For software we do a basic check (e.g. --help or --version)
        else:
            return sn.all([sn.assert_found('manifest module verified:', self.stdout),
                           sn.assert_found(self.baseline_cmd[2], self.stdout)])
