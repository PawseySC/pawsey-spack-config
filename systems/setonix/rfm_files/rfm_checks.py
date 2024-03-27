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

# Each entry of dictionary is list containing command and regex pattern to check for that package
# Format of list is [command, command option/argument, output]
# Some lists have an extra entry, STDERR, which denotes the output is found in stderr rather than stdout
modules_dict = {
        # applications (no ansys-fluids, openfoam, gromacs-amd-gfx90a, nekrs-amd-gfx90a)
        'gromacs/2022.5-double': ['gmx_mpi_d', '--version', 'GROMACS version'],
        'gromacs/2023-double': ['gmx_mpi_d', '--version', 'GROMACS version'],
        'gromacs/2022.5-mixed': ['gmx_mpi', '--version', 'GROMACS version'],
        'gromacs/2023-mixed': ['gmx_mpi', '--version', 'GROMACS version'],
        'cdo': ['cdo', '--help', 'Usage : cdo', 'STDERR'],
        'cp2k': ['cp2k.psmp', '--version', 'CP2K version'],
        #'cpmd': ['cpmd.x', '-h', 'Usage: cpmd.x'], # NOTE: Crashing with MPICH error straightaway
        'lammps': ['lmp', '-h', 'Large-scale Atomic/Molecular Massively Parallel Simulator'],
        'lammps-amd-gfx90a': ['lmp', '-h', 'Large-scale Atomic/Molecular Massively Parallel Simulator'],
        'namd': ['namd2', '-h', 'Info: NAMD'],
        'ncl': ['ncargversion', '', 'NCAR Graphics Software Version'],
        'nco': ['ncdiff', '--help', 'find more help on ncdiff'],
        'ncview': ['ncview', '--help', 'Ncview comes with ABSOLUTELY NO WARRANTY', 'STDERR'],
        'nekrs': ['nekrs', '--help', 'usage:'],
        'nektar': ['IncNavierStokesSolver', '--version', 'Nektar+'],
        'nwchem': ['nwchem', '--help', 'argument  1 = --help'],
        'quantum-espresso': ['ldd', '$(whereis -b simple.x)'], # NOTE: Executing simple.x starts a job, so using ldd instead
        'vasp': ['vasp_std', '--help', 'file INCAR.'],
        'vasp6': ['vasp_std', '--help', 'No INCAR found, STOPPING'],
        # bio-applications
        'beast1': ['beast', '-help', 'Example: beast test.xml'],
        'beast2': ['beast', '-help', 'Example: beast test.xml'],
        'exabayes': ['exabayes', '-h', 'This is ExaBayes, version'],
        'examl': ['examl', '-h', 'This is ExaML version'],
        # astro-applications (no cppzmq)
        'casacore': ['casahdf5support', '', 'HDF5 support'],
        'apr': ['apr-1-config', '-h', 'Usage: apr-1-config'],
        'apr-util': ['apu-1-config', '-h', 'Usage: apu-1-config'],
        'subversion': ['svn', '-h', 'Subversion command-line client.'],
        'cfitsio': ['ldd', 'lib/libcfitsio.so'],
        'pgplot': ['pgbind', '-h', 'Usage: pgbind', 'STDERR'],
        'mcpp': ['mcpp', '-h', 'Usage:  mcpp', 'STDERR'],
        'wcslib': ['fitshdr', '-h', 'Usage: fitshdr', 'STDERR'],
        'wcstools': ['wcshead', '-h', 'usage: wcshead', 'STDERR'],
        'cppunit': ['DllPlugInTester', '-h', 'DllPlugInTester [-c -b -n -t -o -w]'],
        'xerces-c': ['DOMPrint', '-h', 'This program invokes the DOM parser, and builds the DOM tree'],
        #'chgcentre': ['chgcentre', '-h', 'A program to change the phase centre of a measurement set.'], # NOTE: This is crashing straightaway
        'py-emcee': ['python3', '-c "import emcee; print(emcee)"', "module 'emcee'"],
        'py-astropy': ['python3', '-c "import astropy; print(astropy)"', "module 'astropy'"],
        'py-funcsigs': ['python3', '-c "import funcsigs; print(funcsigs)"', "module 'funcsigs'"],
        'py-healpy': ['python3', '-c "import healpy; print(healpy)"', "module 'healpy'"], # NOTE: Not working currently, due to installation issue it seems
        'log4cxx': ['ldd', 'lib64/liblog4cxx.so'],
        'libzmq': ['ldd', 'lib/libzmq.so'],
        # libraries (no eigen, no hpx)
        'hdf5': ['h5dump', '-h', 'usage: h5dump'],
        'petsc': ['ldd', 'lib/libpetsc.so'],
        'netlib-scalapack': ['ldd', 'lib/libscalapack.so'],
        'kokkos': ['hpcbind', '-h', 'Usage: hpcbind'],
        'arpack-ng': ['ldd', 'lib64/libarpack.so'],
        'plumed': ['plumed-config', '-h', 'Check if plumed as dlopen enabled'],
        'fftw/3.3.10': ['fftw-wisdom', '-h', 'Usage: fftw-wisdom'],
        'fftw/2.1.5': ['ldd', 'lib/.so'],
        'slate': ['ldd', 'lib64/libslate.so'],
        'adios2': ['adios2_iotest', '-h', 'Usage: adios_iotest -a appid -c config'],
        'trilinos': ['hpcbind', '-h', 'Usage: hpcbind'],
        'opencv': ['ldd', 'lib64/libopencv_core.so'],
        'boost': ['ldd', 'lib/boost-python3.10/mpi.so'],
        'openblas': ['ldd', 'lib/libopenblas.so'],
        'netcdf-cxx': ['ldd', 'lib/libnetcdf_c++.so'],
        'netlib-lapack': ['ldd', 'lib64/libblas.so'],
        'plasma': ['plasmatest', '-h', 'Available routines:'],
        'charmpp': ['charmrun', '-h', 'Parallel run options:'],
        'parallel-netcdf': ['pnetcdf_version', '-v', 'PnetCDF Version:'],
        'netcdf-fortran': ['nf-config', '--help', 'Usage: nf-config'],
        'netcdf-cxx4': ['ncxx4-config', '--help', 'Usage: ncxx4-config'],
        'blaspp': ['ldd', 'lib64/libblaspp.so'],
        'gsl': ['gsl-config', '-h', 'The GSL CBLAS library is used by default.'],
        'netcdf-c': ['nc-config', '-h', 'Usage: nc-config'],
        # programming-languages
        'r': ['R', '-h', 'R, a system for statistical computation and graphics'],
        'rust': ['rustc', '-h', 'Usage: rustc'],
        'python': ['python', '-h', 'usage: python'],
        'perl': ['perl', '-h', 'Usage: perl'],
        'go': ['go', '-h', 'Go is a tool for managing Go source code.', 'STDERR'],
        'ruby': ['ruby', '-h', 'Usage: ruby'],
        'openjdk': ['java', '--version', 'openjdk 17.0.5 2022-10-18'],
        # utilities
        'cmake': ['cmake', '--version', 'CMake suite maintained and supported by Kitware'],
        'tower-agent': ['tw-agent', '-h', 'Nextflow Tower Agent'],
        'rclone': ['rclone', '-h', 'Rclone syncs files'],
        'ffmpeg': ['ffmpeg', '-h', 'Hyper fast Audio and Video encoder'],
        'automake': ['automake', '--help', 'Generate Makefile.in for configure from Makefile.am.'],
        'tower-cli': ['tw', '-h', 'Nextflow Tower CLI.'],
        'gnuplot': ['gnuplot', '-h', 'Usage: gnuplot'],
        'reframe': ['reframe', '-h', 'Options controlling the ReFrame environment:'],
        'miniocli': ['mc', '-h', 'mc - MinIO Client for object storage and filesystems.'],
        'mpifileutils': ['dcp', '-h', 'Usage: dcp'],
        'parallel': ['parallel', '-h', 'GNU Parallel can do much more'],
        'nano': ['nano', '-h', 'Usage: nano'],
        'nextflow': ['nextflow', '-h', 'Print this help'],
        'singularityce': ['singularity', '-h', 'Linux container platform optimized for High Performance Computing'],
        'feh': ['feh', '-h', 'Usage : feh'],
        'libtool': ['libtool', '-h', 'Provide generalized library-building support services.'],
        'awscli': ['aws', 'help', 'The  AWS  Command  Line  Interface'],
        'autoconf': ['autoconf', '-h', 'Generate a configuration script from a TEMPLATE-FILE if given'],
        # visualisation (None)
        # python-packages
        'py-numpy': ['python3', '-c "import numpy as np; print(np.version)"', "module 'numpy.version'"],
        'py-matplotlib': ['python3', '-c "import matplotlib; print(matplotlib)"', "module 'matplotlib'"],
        'py-scipy': ['python3', '-c "import scipy; print(scipy)"', "module 'scipy'"],
        'py-cython': ['python3', '-c "import cython; print(cython)"', "module 'cython'"],
        'py-pandas': ['python3', '-c "import pandas; print(pandas)"', "module 'pandas'"],
        'py-dask': ['python3', '-c "import dask; print(dask)"', "module 'dask'"],
        'py-numba': ['python3', '-c "import numba; print(numba)"', "module 'numba'"],
        'py-scikit-learn': ['python3', '-c "import sklearn; print(sklearn)"', "module 'sklearn'"],
        'py-h5netcdf': ['python3', '-c "import h5netcdf; print(h5netcdf)"', "module 'h5netcdf'"],
        'py-h5py': ['python3', '-c "import h5py; print(h5py)"', "module 'h5py"],
        'py-netcdf4': ['python3', '-c "import netCDF4; print(netCDF4)"', "module 'netCDF4'"],
        'py-mpi4py': ['python3', '-c "import mpi4py; print(mpi4py)"', "module 'mpi4py'"],
        'py-plotly': ['python3', '-c "import plotly; print(plotly)"', "module 'plotly'"],
        'py-ipython': ['python3', '-c "import IPython; print(IPython)"', "module 'IPython'"],
        # benchmarking
        'osu-micro-benchmarks': ['osu_init', '', '# OSU MPI Init Test'],
        'hpl': ['xhpl', '', 'function HPL_pdinfo', 'STDERR'], # NOTE: Not happy with this one
        'ior': ['ior', '-h', 'Synopsis ior'],
        # developer-tools (no hpcviewer)
        'py-hatchet': ['python3', '-c "import hatchet; print(hatchet)"', "module 'hatchet'"], # NOTE: Not working currently due to installation issue
        'caliper': ['cali-stat', '-h', 'Collect and print statistics about data elements in Caliper streams', 'STDERR'],
        # dependencies (should not be relevant)
}



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
    mod = parameter(get_module_paths())

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
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/16.0.1/astro-applications:{basepath}/modules/zen2/cce/16.0.1/bio-applications:{basepath}/modules/zen2/cce/16.0.1/applications:{basepath}/modules/zen2/cce/16.0.1/libraries:{basepath}/modules/zen2/cce/16.0.1/programming-languages:{basepath}/modules/zen2/cce/16.0.1/utilities:{basepath}/modules/zen2/cce/16.0.1/visualisation:{basepath}/modules/zen2/cce/16.0.1/python-packages:{basepath}/modules/zen2/cce/16.0.1/benchmarking:{basepath}/modules/zen2/cce/16.0.1/developer-tools:{basepath}/modules/zen2/cce/16.0.1/dependencies:{basepath}/custom/modules/zen2/cce/16.0.1/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        # Since zen3 is default, alter MODULEPATH variable if the module is zen2
        if 'zen2' in self.mod:
            install_prefix = os.environ.get('INSTALL_PREFIX')
            modpath = zen2_path.replace('{basepath}', install_prefix)
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
    mod = parameter(get_module_paths())
    
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
        # For log4cxx, which has c++ in module name, which breaks regex search
        if '++' in self.mod:
            self.mod = self.mod.replace('++', '\+\+')
        if '++' in self.name_ver:
            self.name_ver = self.name_ver.replace('++', '\+\+')
        
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
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/16.0.1/astro-applications:{basepath}/modules/zen2/cce/16.0.1/bio-applications:{basepath}/modules/zen2/cce/16.0.1/applications:{basepath}/modules/zen2/cce/16.0.1/libraries:{basepath}/modules/zen2/cce/16.0.1/programming-languages:{basepath}/modules/zen2/cce/16.0.1/utilities:{basepath}/modules/zen2/cce/16.0.1/visualisation:{basepath}/modules/zen2/cce/16.0.1/python-packages:{basepath}/modules/zen2/cce/16.0.1/benchmarking:{basepath}/modules/zen2/cce/16.0.1/developer-tools:{basepath}/modules/zen2/cce/16.0.1/dependencies:{basepath}/custom/modules/zen2/cce/16.0.1/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
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
        # Set executable, accounting for packages which have different commands for different package versions
        version_cmds = ['fftw', 'gromacs']
        version_checks = [v in self.mod for v in version_cmds]
        if any(version_checks):
            self.base_name = self.name_ver
        self.executable = modules_dict[self.base_name][0]
        # Set the executable options, which depends on if it's software or library
        if self.executable == 'ldd':
            lib_path = get_library_path(self.mod.split('/')[-2:])
            self.executable_opts = [lib_path + '/' + modules_dict[self.base_name][1]]
        else:
            self.executable_opts = [modules_dict[self.base_name][1]]
        
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

    mod = parameter(get_module_paths())

    @sanity_function
    def assert_functioning(self):
        # For libraries we check if all libraries are present
        if self.executable == 'ldd':
            return sn.assert_not_found('not found', self.stdout)
        # For software we do a basic check (e.g. --help or --version)
        else:
            # Command output is in either stderr or stdout depending on particular package
            if len(modules_dict[self.base_name]) > 3:
                return sn.assert_found(modules_dict[self.base_name][2], self.stderr)
            else:
                return sn.assert_found(modules_dict[self.base_name][2], self.stdout)
