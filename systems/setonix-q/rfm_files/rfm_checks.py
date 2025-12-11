# Copyright 2016-2021 Swiss National Supercomputing Centre (CSCS/ETH Zurich)
# ReFrame Project Developers. See the top-level LICENSE file for details.
#
# SPDX-License-Identifier: BSD-3-Clause

import reframe as rfm
import reframe.utility.sanity as sn
import reframe.utility.udeps as udeps

import re
import os
import sys
import yaml
import json

# Import file with helper methods for processing spack files needed by below tests
curr_dir = os.path.dirname(__file__).replace('\\','/')
parent_dir = os.path.abspath(os.path.join(curr_dir, os.pardir))
sys.path.append(parent_dir)
from rfm_files.rfm_helper_methods import *

# Dictionary holding commands for every package used in baseline sanity check
pkg_cmds = get_pkg_cmds()
# List of full absolute paths for every explicit module
full_mod_paths = get_module_paths()


@rfm.simple_test
class concretise_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check that every spec in an environment was concretised successfully'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['setonix:login', 'joey:login']
        self.valid_prog_environs = ['PrgEnv-gnu']

        # Execution
        self.executable = 'echo'
        self.executable_opts = ['Checking conretisation success']

        self.tags = {'spack', 'concretization', 'software_stack'}
    
    env = parameter([os.environ['SPACK_ENV']])

    
    @sanity_function
    def assert_concretisation(self):
        abstract_specs = get_abstract_specs()
        root_specs = get_root_specs()
        abstract_name_ver = [None] * len(abstract_specs)
        root_name_ver = [None] * len(root_specs)

        # All abstract specs in {name}/{version} format
        abstract_pattern = r'([\w-]+@*=*[\w.]+).*'
        idx = 0
        for s in abstract_specs:
            match = re.match(abstract_pattern, s)
            if match != None:
                if '@' in match.groups()[0]:
                    abstract_name_ver[idx] = match.groups()[0].split('@')[0] + '/' + match.groups()[0].split('@')[1].replace('=', '')
                else:
                    abstract_name_ver[idx] = match.groups()[0]
            idx += 1

        # All concretised specs in {name}/{version} format
        concrete_pattern = r'^([\w-]+@*=*[\w.]+)'
        idx = 0
        for s in root_specs:
            match = re.match(concrete_pattern, s).groups()[0]
            if '@' in match:
                root_name_ver[idx] = match.split('@')[0] + '/' + match.split('@')[1].replace('=', '')
            else:
                root_name_ver[idx] = match
            idx += 1

        # Check if an abstract spec is missing from the list of concretised specs
        num_failed = 0
        for spec in abstract_name_ver:
            # True if empty list
            if not [m for m in root_name_ver if spec in m]:
                num_failed += 1

        return sn.assert_lt(num_failed, 1)

@rfm.simple_test
class module_existence_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check for existence of a module during software stack installation'
        self.maintainers = ['Craig Meyer']

        # Valid systems and PEs - set PE based on module path
        self.valid_systems = ['setonix:login', 'joey:login']
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']

        # Execution - ls to check the module exists
        self.executable = 'ls'
        self.executable_opts = [self.mod]
        # Get dependencies for the module and add ls commands for those
        dependencies = get_module_dependencies(self.mod)
        if len(dependencies) > 0:
            self.postrun_cmds = [f'ls {d}' for d in dependencies]

        self.tags = {'spack', 'installation', 'software_stack'}
    
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
        self.valid_systems = ['setonix:login', 'joey:login']
        # Choose PE based on the module path
        # NOTE: May need to edit zen2_path in future updates
        cce_version = os.environ.get('cce_version')
        gcc_version = os.environ.get('gcc_version')
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/{cce_version}/astro-applications:{basepath}/modules/zen2/cce/{cce_version}/bio-applications:{basepath}/modules/zen2/cce/{cce_version}/applications:{basepath}/modules/zen2/cce/{cce_version}/libraries:{basepath}/modules/zen2/cce/{cce_version}/programming-languages:{basepath}/modules/zen2/cce/{cce_version}/utilities:{basepath}/modules/zen2/cce/{cce_version}/visualisation:{basepath}/modules/zen2/cce/{cce_version}/python-packages:{basepath}/modules/zen2/cce/{cce_version}/benchmarking:{basepath}/modules/zen2/cce/{cce_version}/developer-tools:{basepath}/modules/zen2/cce/{cce_version}/dependencies:{basepath}/custom/modules/zen2/cce/{cce_version}/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/libraries:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/utilities:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/visualisation:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/python-packages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/{gcc_version}/astro-applications:{basepath}/modules/zen2/gcc/{gcc_version}/bio-applications:{basepath}/modules/zen2/gcc/{gcc_version}/applications:{basepath}/modules/zen2/gcc/{gcc_version}/libraries:{basepath}/modules/zen2/gcc/{gcc_version}/programming-languages:{basepath}/modules/zen2/gcc/{gcc_version}/utilities:{basepath}/modules/zen2/gcc/{gcc_version}/visualisation:{basepath}/modules/zen2/gcc/{gcc_version}/python-packages:{basepath}/modules/zen2/gcc/{gcc_version}/benchmarking:{basepath}/modules/zen2/gcc/{gcc_version}/developer-tools:{basepath}/modules/zen2/gcc/{gcc_version}/dependencies:{basepath}/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/libraries:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/utilities:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/visualisation:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/python-packages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        # Since zen3 is default, alter MODULEPATH variable if the module is zen2
        if 'zen2' in self.mod:
            install_prefix = os.environ.get('INSTALL_PREFIX')
            modpath = zen2_path.replace('{basepath}', install_prefix).replace('{cce_version}', cce_version).replace('{gcc_version}', gcc_version)
            self.prerun_cmds = [f'export MODULEPATH={modpath}']

        # Execution
        self.executable = 'module'
        self.name_ver = '/'.join(self.mod.split('/')[-2:])[:-4]
        self.executable_opts = ['load', self.name_ver]

        # module show to check the correct module is being pointed to
        self.prerun_cmds += [f'module show {self.name_ver}']
        # Check main module is loaded
        self.postrun_cmds = [f'if module is-loaded {self.name_ver} ; then echo "main package is loaded"; fi']

        self.tags = {'spack', 'installation', 'software_stack'}

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
    def check_load_lines(self):
        # Get list of dependencies that need to be loaded - explicit load statements in module file
        self.load_lines = [line.split('load(')[-1][:-2].replace('"', '') for line in open(self.mod).readlines() if line.startswith('load')]
        nloads = len(self.load_lines)
        # `++` breaks the regex search, so replace ++ with \+\+ if present
        for i in range(nloads):
            if '++' in self.load_lines[i]:
                l = self.load_lines[i]
                self.load_lines[i] = l.replace('++', '\+\+')
        # Check all dependencies are loaded
        self.postrun_cmds += [f'if module is-loaded {dep_mod} ; then echo "dependency is loaded"; fi' for dep_mod in self.load_lines]

    @sanity_function
    def assert_module_loaded(self):
        # '+' breaks regex search, need to replace with '\+' in all modules it is present
        if '+' in self.mod:
            self.mod = self.mod.replace('+', '\+')
        if '+' in self.name_ver:
            self.name_ver = self.name_ver.replace('+', '\+')
        
        return sn.all([
            sn.assert_found("main package is loaded", self.stdout),
            sn.assert_eq(sn.count(sn.extractall('dependency is loaded', self.stdout)), len(self.load_lines)),
            sn.assert_found(self.mod, self.stderr),
            sn.assert_not_found('Failed', self.stderr),
            sn.assert_not_found('Error', self.stderr),
        ])


@rfm.simple_test
class baseline_sanity_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check that, once the module is loaded, the software shows the most minimal functionality (--help or --version)'
        self.amintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['setonix:login', 'joey:login']
        # Choose PE based on the module
        # NOTE: May need to edit zen2_path in future updates
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/{cce_version}/astro-applications:{basepath}/modules/zen2/cce/{cce_version}/bio-applications:{basepath}/modules/zen2/cce/{cce_version}/applications:{basepath}/modules/zen2/cce/{cce_version}/libraries:{basepath}/modules/zen2/cce/{cce_version}/programming-languages:{basepath}/modules/zen2/cce/{cce_version}/utilities:{basepath}/modules/zen2/cce/{cce_version}/visualisation:{basepath}/modules/zen2/cce/{cce_version}/python-packages:{basepath}/modules/zen2/cce/{cce_version}/benchmarking:{basepath}/modules/zen2/cce/{cce_version}/developer-tools:{basepath}/modules/zen2/cce/{cce_version}/dependencies:{basepath}/custom/modules/zen2/cce/{cce_version}/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/libraries:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/utilities:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/visualisation:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/python-packages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/{gcc_version}/astro-applications:{basepath}/modules/zen2/gcc/{gcc_version}/bio-applications:{basepath}/modules/zen2/gcc/{gcc_version}/applications:{basepath}/modules/zen2/gcc/{gcc_version}/libraries:{basepath}/modules/zen2/gcc/{gcc_version}/programming-languages:{basepath}/modules/zen2/gcc/{gcc_version}/utilities:{basepath}/modules/zen2/gcc/{gcc_version}/visualisation:{basepath}/modules/zen2/gcc/{gcc_version}/python-packages:{basepath}/modules/zen2/gcc/{gcc_version}/benchmarking:{basepath}/modules/zen2/gcc/{gcc_version}/developer-tools:{basepath}/modules/zen2/gcc/{gcc_version}/dependencies:{basepath}/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/{gcc_version}:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/applications:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/libraries:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/utilities:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/visualisation:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/python-packages:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/{gcc_version}/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/{gcc_version}/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        # Since zen3 is default, alter MODULEPATH variable if the module is zen2
        if 'zen2' in self.mod:
            install_prefix = os.environ.get('INSTALL_PREFIX')
            modpath = zen2_path.replace('{basepath}', install_prefix)
            self.prerun_cmds = [f'export MODULEPATH={modpath}']

        # Load the module we are testing
        self.name_ver = '/'.join(self.mod.split('/')[-2:])[:-4]
        self.modules = [self.name_ver]

        # Execution - call executable with `--help` or `--version` option
        self.base_name = self.mod.split('/')[-2] # Extract package/library name from full module path
        self.mod_category = self.mod.split('/')[-3]
        # Set executable, accounting for packages which have different commands for different package versions
        version_cmds = ['fftw', 'gromacs']
        version_checks = [v in self.mod for v in version_cmds]
        if any(version_checks):
            self.base_name = self.name_ver
        self.executable = pkg_cmds[self.mod_category][self.base_name][0]
        # Set the executable options, which depends on if it's software or library
        if (self.executable == 'ldd') or (self.base_name == 'hpx'):
            lib_path = get_library_path(self.mod.split('/')[-2:])
            self.executable_opts = [lib_path + '/' + pkg_cmds[self.mod_category][self.base_name][1]]
        else:
            self.executable_opts = [pkg_cmds[self.mod_category][self.base_name][1] + ' 2>&1']
        
        self.tags = {'spack', 'installation', 'software_stack'}

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
            return sn.assert_not_found('not found', self.stdout)
        # For software we do a basic check (e.g. --help or --version)
        else:
            return sn.assert_found(pkg_cmds[self.mod_category][self.base_name][2], self.stdout)
