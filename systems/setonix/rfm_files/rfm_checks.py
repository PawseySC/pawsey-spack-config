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

curr_dir = os.path.dirname(__file__).replace('\\','/')
parent_dir = os.path.abspath(os.path.join(curr_dir, os.pardir))
#root_dir = os.path.abspath(os.path.join(parent_dir, os.pardir))
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


# def get_env_vars():

#     # Population dictionary with necessary environment variables, setting appropriate defaults if not set
#     env_dict = {}

#     env_dict['env'] = os.getenv('SPACK_ENV')
#     env_dict['spack_repo_path'] = os.getenv('PAWSEY_SPACK_CONFIG_REPO')
#     env_dict['install_prefix'] = os.getenv('INSTALL_PREFIX')
#     env_dict['python_version'] = os.getenv('python_version')
#     env_dict['gcc_version'] = os.getenv('gcc_version')
#     env_dict['cce_version'] = os.getenv('cce_version')
#     env_dict['system'] = os.getenv('SYSTEM') or 'setonix'

#     return env_dict

# # Get the full set of abstract specs for an environemtn from the spack.yaml file
# def get_abstract_specs():

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     system = env_dict['system']
    
#     # Abstract specs we wish to install
#     abstract_specs = []
#     yaml_file = f'{repo_path}/systems/{system}/environments/{env}/spack.yaml'
#     with open(yaml_file, "r") as stream:
#         data = yaml.safe_load(stream)

#     # The spec categories (in the matrices in the spack.yaml file)
#     spec_categories = []
#     for entry in data['spack']['specs']:
#         m = entry['matrix']
#         # Only add those categories which start with '$', which are expanded out
#         if m[0][0][0] == '$':
#             spec_categories.append(m[0][0][1:])

#     # Regex pattern to pick out valid package spec definitions
#     pattern = r'([\w-]+@*=*[\w.]+).*'
#     for entry in data['spack']['definitions']:
#         # Iterate over each group of packages
#         for key, value in entry.items():
#             # Select only those categories which are listed in the matrices
#             if key in spec_categories:
#                 # Add each individual packages spec in this group
#                 for elem in value:
#                     abstract_specs.append(elem)

#     # Handle cases where specs are defined within a matrix rather than with other packages (e.g. cmake in utils env)
#     for entry in data['spack']['specs']:
#         for key, value in entry.items():
#             if value[0][0][0] != '$':
#                 abstract_specs.append(value[0][0])
    
#     # Sort the list and return
#     return sorted(abstract_specs)

# # Get spec (plus full hash) for each root package in an environment from spack.lock file
# def get_root_specs():

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     system = env_dict['system']

#     # Fully concretised spacks generated from concretisation
#     root_specs = []
#     lock_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
#     with open(lock_file) as json_data:
#         data = json.load(json_data)
    
#     # Regex pattern to extract spec name and version
#     pattern = r'^([\w-]+@*=*[\w.]+)'
#     # Iterate over every package
#     for entry in data['roots']:
#         # Get full spec and hash for each package
#         s = entry['spec']
#         h = entry['hash']
#         root_specs.append(s + ' ' + h)


#     # Sort the list and return
#     return sorted(root_specs)


# # Get concrete spec for every root package across every environment
# def get_all_root_specs():

#     env_list = [
#         'utils', 'num_libs', 'python', 'io_libs', 'langs', 'apps', 'devel', 'bench', 's3_clients', 'astro', 'bio', 'roms', 'wrf',
#         'cray_utils', 'cray_num_libs', 'cray_python', 'cray_io_libs', 'cray_langs', 'cray_devel', 'cray_s3_clients'
#     ]
#     env_dict = get_env_vars()
#     repo_path = env_dict['spack_repo_path']
#     system = env_dict['system']

#     # Regex pattern to extract spec name and version
#     pattern = r'^([\w-]+@*=*[\w.]+)'
#     # Extract specs from spack.lock files in every environment
#     root_specs = []
#     file_paths = [f'{repo_path}/systems/{system}/environments/{env}/spack.lock' for env in env_list]
#     for file_path in file_paths:
#         with open(file_path) as json_data:
#             data = json.load(json_data)

#             # Iterate over every root package in this file
#             specs = []
#             for entry in data['roots']:
#                 # Get full spec and hash for each package
#                 s = entry['spec']
#                 h = entry['hash']
#                 specs.append(s + ' ' + h)
#             root_specs.extend(specs)

#     return root_specs


# # Function to process specs where part of the module path is not present in the
# # concretised spec identifier, but instead is only present in the `paramaters` dictinoary 
# # entry of the full dictionary of the spec in the spack.lock file
# # NOTE: As of 2024.02, this is needed for xerces-c and wcslib
# def special_case(pkg_name, base_spec, conc_data, pkg_hash):

#     # For xerces-c the module path includes the transcoder, which is not specified in the base spec
#     if pkg_name == 'xerces-c':
#         new_spec = base_spec + (' ' + 'transcoder=' + conc_data['concrete_specs'][pkg_hash]['parameters']['transcoder'])
#     # For wcslib, the use (or lack thereof) of cfitsio is in the module path, but not in the base spec
#     elif pkg_name == 'wcslib':
#         icfits = conc_data['concrete_specs'][pkg_hash]['parameters']['cfitsio']
#         if icfits:
#             if '+cfitsio' not in base_spec:
#                 new_spec = base_spec + (' ' + '+cfitsio')
#         else:
#             if '~cfitsio' not in base_spec:
#                 new_spec = base_spec + (' ' + '~cfitsio')
    
#     return new_spec

# # Function to process projections where inclusions marked by "+" and exclusions marked by "~"
# # which are included in module name are not separate by whitespace " " in spec
# # NOTE: As of 2024.02, this is needed for petsc and hdf5
# def process_projections(variants):

#     # Modify the original list of package variants
#     new_variants = variants

#     # Iterate through every variant
#     for v in variants:
#         # If of the form "+{var}~{var}" or "~{var}+{var}" need to separate the two components, keeping the '+' and '~' symbols
#         if ('+' in v) and ('~' in v):
#             if v[0] == '+':
#                 tmp_var = v.split('~')
#                 tmp_var[-1] = '~' + tmp_var[-1]
#             elif v[0] == '~':
#                 tmp_var = v.split('+')
#                 tmp_var[-1] = '+' + tmp_var[-1]
#             new_variants = new_variants + tmp_var
#         # If of the form "~{var}~{var}" or "+{var}+{var}" need to separate the two components, keeping both '~'
#         elif '~' in v:
#             tmp_var = v.split('~')
#             tmp_var = ['~' + entry for entry in tmp_var[1:]]
#             new_variants = new_variants + tmp_var
#         elif '+' in v:
#             tmp_var = v.split('+')
#             tmp_var = ['+' + entry for entry in tmp_var[1:]]
#             new_variants = new_variants + tmp_var
    
#     return new_variants

# # Get path to the shared object libraries for a package
# def get_library_path(pkg_name_ver):

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     install_prefix = env_dict['install_prefix']
#     system = env_dict['system']

#     # Get root specs for this environment
#     root_specs = get_root_specs()

#     # Get full concrete specs for this environment
#     # Since format of root spec isn't universally consistent, this makes for easier extraction of name, version, compiler, architecture, etc.
#     json_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
#     with open(json_file) as json_data:
#         conc_data = json.load(json_data)

#     # Iterate over every spec
#     pkg_name = pkg_name_ver[0]
#     pkg_ver = pkg_name_ver[1][:-4]
#     # Handle packages with specifiers after version in module file (e.g. of the form petsc/3.19.5-complex)
#     # log4cxx is treated separately since it has package version and C++ version in module file
#     if ('-' in pkg_ver) and (pkg_name != 'log4cxx'): 
#         pkg_ver = pkg_ver.split('-')[0]
    
#     for idx, s in enumerate(root_specs):
#         # Hash is last entry in spec
#         h = s.split(' ')[-1]
#         name = conc_data['concrete_specs'][h]['name']
#         ver = conc_data['concrete_specs'][h]['version']
#         if 'log4cxx' in name: # log4cxx also has the C++ version in the module path
#             c_ver = conc_data['concrete_specs'][h]['parameters']['cxxstd']
#             if (name == pkg_name) and (ver in pkg_ver) and (c_ver in pkg_ver):
#                 comp = conc_data['concrete_specs'][h]['compiler']['name'] + '-' + conc_data['concrete_specs'][h]['compiler']['version']
#                 arch = conc_data['concrete_specs'][h]['arch']['target']['name']
#                 lib_path = f'{install_prefix}/software/linux-sles15-{arch}/{comp}/{name}-{ver}-{h}'
#                 break
#         else:
#             if (name == pkg_name) and (ver == pkg_ver):
#                 comp = conc_data['concrete_specs'][h]['compiler']['name'] + '-' + conc_data['concrete_specs'][h]['compiler']['version']
#                 arch = conc_data['concrete_specs'][h]['arch']['target']['name']
#                 lib_path = f'{install_prefix}/software/linux-sles15-{arch}/{comp}/{name}-{ver}-{h}'
#                 break

#     return lib_path

# # Build a spec of the format of those specified in the `roots` section of the spack.lock file
# def build_root_spec(conc_spec, param_dict):

#     # Get package information from the full concrete spec
#     name = conc_spec['name']
#     ver = conc_spec['version']
#     h = conc_spec['hash']
#     comp_name = conc_spec['compiler']['name']
#     comp_ver = conc_spec['compiler']['version']

#     # Start with the basic components of the spec
#     root_spec = name + '@' + ver + '%' + comp_name + '@' + comp_ver

#     # Add to spec from the parameters dictionary of the concrete spec
#     # Only add the True/False parameter values in the format of +param and ~param
#     for key, val in param_dict.items():
#         if val == False:
#             root_spec += ('~' + key)
#         elif val == True:
#             root_spec += ('+' + key)
#         elif isinstance(val, list):
#             continue
        
#     # Add key-value parameters from parameters dictionary of the
#     # concrete spec in the format key=value
#     for key, val in param_dict.items():
#         if isinstance(val, list):
#             continue
#         if (val != False) and (val != True):
#             root_spec += (' ' + key + '=' + val)
    
#     # Add the hash to the end of the spec
#     root_spec += (' ' + h)

#     return root_spec

# # Get full module path for this package
# # NOTE: This is used primarily for dependencies, which are not root packages of any of the environments
# def get_dependency_module_path(pkg_info, conc_data, pkg_spec):
#     # List of specs which need extra hardcoded work to match conretsied spec to full module path
#     special_cases = ['xerces-c', 'wcslib']

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     install_prefix = env_dict['install_prefix']
#     system = env_dict['system']
#     python_ver = env_dict['python_version']

#     # Master module file describing format of full module path across all environments
#     yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
#     with open(yaml_file, "r") as stream:
#         mod_data = yaml.safe_load(stream) 
#     # Projections describe module paths for each package
#     projections = mod_data['modules']['default']['lmod']['projections']
#     projs = []
#     paths = []
#     # Fill lists with corresponding projections and paths
#     for proj in projections:
#         paths.append(projections[proj])
#         projs.append(proj)

#     # Details of dependency
#     name = pkg_info['name']
#     h = pkg_info['hash']
#     version  = pkg_info['version']
#     comp = pkg_info['compiler']['name'] + '/' + pkg_info['compiler']['version']
#     arch = pkg_info['arch']['target']['name']

#     # Get index of this package in the set of all concretised specs by matching hashes
#     hashes = [c for c in conc_data['concrete_specs']]
#     idx = [i for i, j in enumerate(hashes) if j == h][0]

#     # Find mathching projection for the spec of this package
#     matching_projections = []
#     for p_idx, p in enumerate(projs):
#         # Split projection into list of specifiers
#         specifiers = p.split(' ')
#         if name in p:
#             mask = ['~' not in s for s in specifiers]
#             # Iterate through all variants, updating if needed
#             updated_specifiers = [b for a, b in zip(mask, specifiers) if a]
#             # If all specifiers of a variant are present in the package spec, it matches
#             if all(s in pkg_spec for s in updated_specifiers):
#                 matching_projections.append(p)

#     # Handle dependencies which are a partial match to a projection, but not a full match
#     # These are then hidden module files in the dependencies directory
#     # One example is boost/1.80.0 dependency for hpx/1.8.1 - there are explicit boost projections, 
#     # but this particular boost variant does not have a matching projection,
#     # so it goes under dependencies catch-all projection
#     if len(matching_projections) == 0:
#         full_mod_path = f'{install_prefix}/modules/{arch}/{comp}/' + paths[-1].replace('{name}', name).replace('{version}', version).replace('{hash:7}', h[:7]) + '.lua'
#         return full_mod_path
        

#     # There is more than one possible matching projection
#     if len(matching_projections) > 1:
#         nmatches = []
#         for idx, proj in enumerate(matching_projections):
#             # Split projection into it's components (i.e. "gromacs +double" -> ['gromacs', '+double'])
#             tmp = proj.split(' ')
#             # petsc and hdf5 specs structured differently to all others, needs special treatment
#             if 'petsc' == matching_projections[0][0:5]:
#                 tmp = process_projections(tmp)
#             if 'hdf5' == matching_projections[0][0:4]:
#                 tmp = process_projections(tmp)
#             # Number of keywords in this projection which are found in the package concretised spec
#             nmatches.append(sum([keyword in pkg_spec for keyword in tmp]))
#         # Pick the projection which has the most keyword matches
#         max_idx = max(enumerate(nmatches), key=lambda x: x[1])[0]
#         matched_proj = matching_projections[max_idx]
#     # There is only one matched projection
#     else:
#         matched_proj = matching_projections[0]


#     # Get module path for the matched projection
#     for p_idx, p in enumerate(projs):
#         if p == matched_proj:
#             # Do we need to include the python version (e.g. for mpi4py)?
#             if '^python.version' in paths[p_idx]:
#                 matching_mod_path = paths[p_idx].replace('{name}', name).replace('{version}', version).replace('{^python.version}', python_ver)
#             # Standard projection
#             else:
#                 matching_mod_path = paths[p_idx].replace('{name}', name).replace('{version}', version)

#     # Convert the matching module path into full absolute path
#     full_mod_path = install_prefix + f'/modules/{arch}/{comp}/' + matching_mod_path + '.lua'

#     return full_mod_path

# # Get the full module paths for all dependencies for this package
# def get_module_dependencies(pkg_module_path):

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     install_prefix = env_dict['install_prefix']
#     system = env_dict['system']
#     python_ver = env_dict['python_version']

#     # Get root specs from the environment this package is in
#     root_specs = get_root_specs()

#     yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
#     with open(yaml_file, "r") as stream:
#         mod_data = yaml.safe_load(stream)    
#     # Projections describe module paths for each spec
#     projections = mod_data['modules']['default']['lmod']['projections']
#     projs = []
#     paths = []
#     # Fill lists with corresponding projections and paths
#     for proj in projections:
#         paths.append(projections[proj])
#         projs.append(proj)

#     # Process json .lock files for every environment to get every concrete spec in the stack
#     env_list = [
#         'utils', 'num_libs', 'python', 'io_libs', 'langs', 'apps', 'devel', 'bench', 's3_clients', 'astro', 'bio', 'roms', 'wrf',
#         'cray_utils', 'cray_num_libs', 'cray_python', 'cray_io_libs', 'cray_langs', 'cray_devel', 'cray_s3_clients'
#     ]
#     conc_data = []
#     file_paths = [f'{repo_path}/systems/{system}/environments/{env}/spack.lock' for env in env_list]
#     for file_path in file_paths:
#         with open(file_path) as json_data:
#             c = json.load(json_data)
#             conc_data.append(c)
#     # Format data to get all concretised specs for all packages in all environments
#     all_conc_data = {k: [d[k] for d in conc_data] for k in conc_data[0]}
#     tmp_specs = [c for d in all_conc_data['concrete_specs'] for c in d]
#     tmp_specs = {}
#     for d in all_conc_data['concrete_specs']:
#         tmp_specs.update(d)
#     all_conc_data['concrete_specs'] = tmp_specs
    
#     # List to hold full absolute module paths for every dependency of this package
#     dep_paths = []

#     # Get relevant package info (name, ver, compiler, architecture) from full module path
#     pkg_info = pkg_module_path[:-4].split('/')[-6:]
#     if '-' in pkg_info[-1]: # Handle those modules with info between version and .lua file extension
#         pkg_info = pkg_info[:-1] + [pkg_info[-1].split('-')[0]]

#     # Iterate over every root spec across all environments
#     for idx, s in enumerate(root_specs):
#         # Hash is last entry in spec
#         h = s.split(' ')[-1]
#         # Get full concrete specs for this root spec
#         c = all_conc_data['concrete_specs'][h]
#         name = c['name']
#         ver = c['version']
#         comp_name = c['compiler']['name']
#         comp_ver = c['compiler']['version']
#         arch = c['arch']['target']['name']
#         # This root spec is a full match for this module
#         if all(map(lambda v: v in pkg_info, [name, ver, comp_name, comp_ver, arch])):
#             # Check if it has any dependencies
#             key_list = [k for k in c.keys()]
#             if 'dependencies' in key_list:
#                 deps = c['dependencies']
#                 # Iterate through dependencies
#                 for d in deps:
#                     dh = d['hash']
#                     dc = all_conc_data['concrete_specs'][dh]
#                     d_comp = dc['compiler']['name'] + '/' + dc['compiler']['version']
#                     d_arch = dc['arch']['target']['name']
#                     # Treat git separately
#                     if dc['name'] == 'git':
#                         path = f'{install_prefix}/modules/{d_arch}/{d_comp}/' + paths[-2].replace('{version}', dc['version']).replace('{hash:7}', dh[:7]) + '.lua'
#                     else:
#                         # See if any projections are at least a partial match to this dependency
#                         nchars = len(dc['name'])
#                         proj_matches = [dc['name'] == proj[0:nchars] for proj in projs]
#                         if any(proj_matches):
#                             # Build a "root spec" for this dependency and get its full module path
#                             built_spec = build_root_spec(dc, dc['parameters'])
#                             path = get_dependency_module_path(dc, all_conc_data, built_spec)
#                         # There is not even a partial projection match, so it falls under the dependencies catch-all projection
#                         else:
#                             path = f'{install_prefix}/modules/{d_arch}/{d_comp}/' + paths[-1].replace('{name}', dc['name']).replace('{version}', dc['version']).replace('{hash:7}', dh[:7]) + '.lua'
#                     dep_paths.append(path)
    
#     return dep_paths

# # Get full absolute module paths for every package in an environment
# def get_module_paths():
#     # List of specs which need extra hardcoded work to match conretsied spec to full module path
#     special_cases = ['xerces-c', 'wcslib']

#     # Get required environment variables
#     env_dict = get_env_vars()
#     env = env_dict['env']
#     repo_path = env_dict['spack_repo_path']
#     install_prefix = env_dict['install_prefix']
#     python_ver = env_dict['python_version'] # Some python packages include python version in their name (e.g. mpi4py)
#     system = env_dict['system']

#     # Get root specs for this environment (from environments/{env}/spack.lock file)
#     # Three lists - full concretised spec, reduced list in format {name}/{version}, and hash
#     root_specs = get_root_specs()
#     root_name_ver = [None] * len(root_specs)
#     hashes = [None] * len(root_specs)
#     arches = [None] * len(root_specs)
#     compilers = [None] * len(root_specs)

#     #########################################
#     # Convert full spec to name and version #
#     #########################################
#     # File containging concrete specs
#     json_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
#     with open(json_file) as json_data:
#         conc_data = json.load(json_data)

#     # Given root spec is not in universally consistent format, use full concrete specs to get compilers, architecture, etc.
#     for idx, s in enumerate(root_specs):
#         # Hash is last entry in spec
#         h = s.split(' ')[-1]
#         hashes[idx] = h
#         comp = conc_data['concrete_specs'][h]['compiler']['name'] + '/' + conc_data['concrete_specs'][h]['compiler']['version']
#         compilers[idx] = comp
#         arch = conc_data['concrete_specs'][h]['arch']['target']['name']
#         arches[idx] = arch
#         root_name_ver[idx] = conc_data['concrete_specs'][h]['name'] + '/' + conc_data['concrete_specs'][h]['version']


#     ##################################################
#     # Matching concretised specs to full module path #
#     ##################################################
#     # Master module file describing format of full module path across all environments
#     yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
#     with open(yaml_file, "r") as stream:
#         mod_data = yaml.safe_load(stream)    
#     # Projections describe module paths for each spec
#     projections = mod_data['modules']['default']['lmod']['projections']
#     projs = []
#     paths = []
#     # Fill lists with corresponding projections and paths
#     for proj in projections:
#         paths.append(projections[proj])
#         projs.append(proj)

#     # Match each projection with the corresponding abstract spec
#     matching_projections = [ [] for _ in range(len(root_specs))]
#     for c_idx, c_spec in enumerate(root_specs):
#         # Extract name of module from {name}/{version} entries
#         name = root_name_ver[c_idx].split('/')[0]
#         # Iterate through each projection
#         for p_idx, p in enumerate(projs):
#             # If there are variants, extra specifications will be separated from name by ' '
#             # Examples: gromacs vs. gromacs +double, lammps ~rocm vs. lammps +rocm
#             specifiers = p.split(' ')
#             # If the name of this concretised spec is within this projection
#             if name in p:
#                 # Handle special cases (part of module path is not in root spec, but is in concretised spec dict entry in .lock file)
#                 if name in special_cases:
#                     updated_spec = special_case(name, c_spec, conc_data, hashes[c_idx])
#                     root_specs[c_idx] = updated_spec
#                 # Update `c_spec` (will only differ from c_spec for special cases)
#                 updated_c_spec = root_specs[c_idx]
#                 # Filter variants, removing entries with `~` since it denotes the lack of something
#                 mask = ['~' not in s for s in specifiers]
#                 # Iterate through all specifiers, updating if needed
#                 updated_specifiers = [b for a, b in zip(mask, specifiers) if a]
#                 # If all specifiers of a projection are present in the spec, it matches
#                 if all(s in updated_c_spec for s in updated_specifiers):
#                     matching_projections[c_idx].append(p)

#     # Multiple projections can match a single spec, we need to pick the one true match
#     # Example: A spec with "gromacs +double" can be matched by both "gromacs" and "gromacs +double" projections
#     for m_idx, m in enumerate(matching_projections):
#         # If there is more than one matching projection for this spec
#         if len(m) > 1:
#             # List to hold the number of keywords in each possible match that are found in the concretised spec
#             # The possible match with the highest number of keyword matches is selected as the correct match
#             # Example: "gromacs +double" is matched with both "gromacs" and "gromacs +double" projections
#             # so "gromacs +double" has 2 matches and "gromacs" just 1, so "gromacs +double" projection is chosen
#             nmatches = []
#             for idx, proj in enumerate(m):
#                 # Split projection into it's components (i.e. "gromacs +double" -> ['gromacs', '+double'])
#                 tmp = proj.split(' ')
#                 # petsc/hdf5 specs structured differently to all others, needs special treatment
#                 if 'petsc' == m[0][0:5]:
#                     tmp = process_projections(tmp)
#                 if 'hdf5' == m[0][0:4]:
#                     tmp = process_projections(tmp)
#                 # Number of keywords in this variant which are found in the full concretised spec
#                 nmatches.append(sum([keyword in root_specs[m_idx] for keyword in tmp]))
#             # Find projectionn with highest number of keyword matches
#             max_idx = max(enumerate(nmatches), key=lambda x: x[1])[0]
#             matching_projections[m_idx] = [m[max_idx]]
            
    
#     # Account for dependencies (e.g. llvm) which give len(m) == 0
#     # Need to update all lists to exclude dependencies
#     mask = [len(m) > 0 for m in matching_projections]
#     # Convert from list of lists to list of strings
#     matching_projections = [m[0] for m in matching_projections if len(m) > 0]
#     # Select the concretised specs that aren't dependencies using selection mask
#     updated_root_name_ver = [b for a, b in zip(mask, root_name_ver) if a]
#     updated_arches = [b for a, b in zip(mask, arches) if a]
#     updated_compilers = [b for a, b in zip(mask, compilers) if a]

#     # List to hold module paths for matched projection of each abstract spec
#     matching_mod_paths = [None for _ in range(len(matching_projections))]
#     for m_idx, m in enumerate(matching_projections):
#         # Name and version are both included
#         if '/' in updated_root_name_ver[m_idx]:
#             name, ver = updated_root_name_ver[m_idx].split('/')
#         # No version information in the spec, need to search spec dictionary entry in .lock file
#         else:
#             name = updated_root_name_ver[m_idx]
#             cs = conc_data['concrete_specs']
#             ver = cs[hashes[m_idx]]['version']
#         for p_idx, p in enumerate(projs):
#             # This projection matches one of the abstract specs
#             if p == m:
#                 # Do we need to include the python version (e.g. for mpi4py)?
#                 if '^python.version' in paths[p_idx]:
#                     matching_mod_paths[m_idx] = paths[p_idx].replace('{name}', name).replace('{version}', ver).replace('{^python.version}', python_ver)
#                 # Standard projection
#                 else:
#                     matching_mod_paths[m_idx] = paths[p_idx].replace('{name}', name).replace('{version}', ver)

#     # Convert the matching module paths into full absolute paths
#     full_mod_paths = [None] * len(matching_mod_paths)
#     for i in range(len(matching_mod_paths)):
#         compiler = 'cce/' + env_dict['cce_version'] if 'cce' in updated_compilers[i] else 'gcc/' + env_dict['gcc_version']
#         arch = updated_arches[i]
#         full_mod_paths[i] = install_prefix + f'/modules/{arch}/{compiler}/' + matching_mod_paths[i] + '.lua'

#     return full_mod_paths



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

        # Valid systems and PEs
        self.valid_systems = ['setonix:login', 'joey:login']
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']

        # Execution
        self.executable = 'ls'
        module_path = self.mod
        self.executable_opts = [module_path]
        #print(self.mod)
        dependencies = get_module_dependencies(self.mod)
        #dependencies = get_module_dependencies(self.mod.split('/')[-2:])
        if len(dependencies) > 0:
            self.postrun_cmds = [f'ls {d}' for d in dependencies]
            #print(self.postrun_cmds)
        #condition = [sn.assert_found(d, self.stderr) for d in dependencies]

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
        # Choose PE based on the module
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/16.0.1/astro-applications:{basepath}/modules/zen2/cce/16.0.1/bio-applications:{basepath}/modules/zen2/cce/16.0.1/applications:{basepath}/modules/zen2/cce/16.0.1/libraries:{basepath}/modules/zen2/cce/16.0.1/programming-languages:{basepath}/modules/zen2/cce/16.0.1/utilities:{basepath}/modules/zen2/cce/16.0.1/visualisation:{basepath}/modules/zen2/cce/16.0.1/python-packages:{basepath}/modules/zen2/cce/16.0.1/benchmarking:{basepath}/modules/zen2/cce/16.0.1/developer-tools:{basepath}/modules/zen2/cce/16.0.1/dependencies:{basepath}/custom/modules/zen2/cce/16.0.1/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
            #zen2_path = '{basepath}/modules/zen2/gcc/12.2.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        # Since zen3 is default, alter MODULEPATH variable if the module is zen2
        if 'zen2' in self.mod:
            #zen2_path = '{basepath}/modules/zen2/gcc/12.2.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
            install_prefix = os.environ.get('INSTALL_PREFIX')
            modpath = zen2_path.replace('{basepath}', install_prefix)
            #os.environ['MODULEPATH'] = modpath
            #print(modpath)
            self.prerun_cmds = [f'export MODULEPATH={modpath}']

        # Execution
        self.executable = 'module'
        self.name_ver = '/'.join(self.mod.split('/')[-2:])[:-4]
        self.executable_opts = ['load', self.name_ver]

        # To check the module is loaded and that the module loaded matches the full module path
        self.prerun_cmds += [f'module show {self.name_ver}']
        self.postrun_cmds = [f'if module is-loaded {self.name_ver} ; then echo "main package is loaded"; fi']
        #self.postrun_cmds = ['module list >> modules.txt 2>&1']#, f'module show {self.name_ver}']

        #self.keep_files = ['modules.txt']
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
        # Get list of dependencies that need to be loaded
        self.load_lines = [line.split('load(')[-1][:-2].replace('"', '') for line in open(self.mod).readlines() if line.startswith('load')]
        nloads = len(self.load_lines)
        #print(self.load_lines)
        #print(nloads)
        for i in range(nloads):
            if '++' in self.load_lines[i]:
                l = self.load_lines[i]
                self.load_lines[i] = l.replace('++', '\+\+')
        #self.load_lines = [l.replace('++', '\+\+') for l in self.load_lines if '++' in l]
        #print('load lines = ', self.load_lines)
        #print(nloads)
        
        self.postrun_cmds += [f'if module is-loaded {dep_mod} ; then echo "dependency is loaded"; fi' for dep_mod in self.load_lines]

    @sanity_function
    def assert_module_loaded(self):
        # # Get list of dependencies that need to beloaded
        # self.load_lines = [line.split('load(')[-1][:-2].replace('"', '') for line in open(self.mod).readlines() if line.startswith('load')]
        # print(self.load_lines)
        # self.load_lines = [l.replace('++', '\+\+') for l in self.load_lines if '++' in l]
        # print('load lines = ', self.load_lines)

        condition = [sn.assert_found(l, self.stderr) for l in self.load_lines]

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

        # return sn.all(condition + [
        #         sn.assert_found(self.name_ver, 'modules.txt'),#self.stderr),
        #         sn.assert_found(self.mod, self.stderr),
        #         sn.assert_not_found('Failed', self.stderr),
        #         sn.assert_not_found('Error', self.stderr),
        #     ])
        
        # dependencies = get_module_dependencies(self.mod.split('/')[-2:])
        # # No dependencies for this package
        # if len(dependencies) == 0:
        #     return sn.all([
        #         sn.assert_found(self.name_ver, self.stderr),
        #         sn.assert_found(self.mod, self.stderr),
        #         sn.assert_not_found('Failed', self.stderr),
        #         sn.assert_not_found('Error', self.stderr),
        #     ])
        # else:
        #     condition = [sn.assert_found(d, self.stderr) for d in dependencies]
        #     print("CONDITION = ", condition)
        #     return sn.all(condition)


@rfm.simple_test
class baseline_sanity_check(rfm.RunOnlyRegressionTest):
    def __init__(self):

        # Metadata
        self.descr = 'Test to check that, once the module is loaded, the software shows the most minimal functionality (--help or --version)'
        self.amintainers = ['Craig Meyer']

        # Valid systems and PEs
        self.valid_systems = ['setonix:login', 'joey:login']
        #self.valid_prog_environs = ['PrgEnv-gnu']
        # Choose PE based on the module
        if 'cce' in self.mod:
            self.valid_prog_environs = ['PrgEnv-cray']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/crayclang/14.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/cce/16.0.1/astro-applications:{basepath}/modules/zen2/cce/16.0.1/bio-applications:{basepath}/modules/zen2/cce/16.0.1/applications:{basepath}/modules/zen2/cce/16.0.1/libraries:{basepath}/modules/zen2/cce/16.0.1/programming-languages:{basepath}/modules/zen2/cce/16.0.1/utilities:{basepath}/modules/zen2/cce/16.0.1/visualisation:{basepath}/modules/zen2/cce/16.0.1/python-packages:{basepath}/modules/zen2/cce/16.0.1/benchmarking:{basepath}/modules/zen2/cce/16.0.1/developer-tools:{basepath}/modules/zen2/cce/16.0.1/dependencies:{basepath}/custom/modules/zen2/cce/16.0.1/custom:/opt/cray/pe/lmod/modulefiles/comnet/crayclang/14.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/compiler/crayclang/14.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        elif 'gcc' in self.mod:
            self.valid_prog_environs = ['PrgEnv-gnu']
            zen2_path = '/opt/cray/pe/lmod/modulefiles/mpi/gnu/8.0/ofi/1.0/cray-mpich/8.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:{basepath}/containers/views/modules:{basepath}/pawsey/modules:/software/projects/pawsey0001/cmeyer/setonix/2024.02/containers/views/modules:{basepath}/staff_modulefiles:/software/projects/pawsey0001/cmeyer/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/projects/pawsey0001/setonix/2023.08/modules/zen2/gcc/12.2.0:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/astro-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/bio-applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/applications:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/libraries:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/programming-languages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/utilities:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/visualisation:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/python-packages:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/benchmarking:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/developer-tools:/software/setonix/2023.08/modules/zen2/gcc/12.2.0/dependencies:/software/setonix/2023.08/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
            #zen2_path = '{basepath}/modules/zen2/gcc/12.2.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
        # Since zen3 is default, alter MODULEPATH variable if the module is zen2
        if 'zen2' in self.mod:
            #zen2_path = '{basepath}/modules/zen2/gcc/12.2.0:{basepath}/modules/zen2/gcc/12.2.0/astro-applications:{basepath}/modules/zen2/gcc/12.2.0/bio-applications:{basepath}/modules/zen2/gcc/12.2.0/applications:{basepath}/modules/zen2/gcc/12.2.0/libraries:{basepath}/modules/zen2/gcc/12.2.0/programming-languages:{basepath}/modules/zen2/gcc/12.2.0/utilities:{basepath}/modules/zen2/gcc/12.2.0/visualisation:{basepath}/modules/zen2/gcc/12.2.0/python-packages:{basepath}/modules/zen2/gcc/12.2.0/benchmarking:{basepath}/modules/zen2/gcc/12.2.0/developer-tools:{basepath}/modules/zen2/gcc/12.2.0/dependencies:{basepath}/custom/modules/zen2/gcc/12.2.0/custom:/opt/cray/pe/lmod/modulefiles/comnet/gnu/8.0/ofi/1.0:/opt/cray/pe/lmod/modulefiles/mix_compilers:/opt/cray/pe/lmod/modulefiles/compiler/gnu/8.0:/opt/cray/pe/lmod/modulefiles/perftools/23.03.0:/opt/cray/pe/lmod/modulefiles/net/ofi/1.0:/opt/cray/pe/lmod/modulefiles/cpu/x86-milan/1.0:/opt/cray/pe/modulefiles/Linux:/opt/cray/pe/modulefiles/Core:/opt/cray/pe/lmod/lmod/modulefiles/Core:/opt/cray/pe/lmod/modulefiles/core:/opt/cray/pe/lmod/modulefiles/craype-targets/default:/opt/pawsey/modulefiles:/software/pawsey/modulefiles:/opt/cray/modulefiles'
            install_prefix = os.environ.get('INSTALL_PREFIX')
            modpath = zen2_path.replace('{basepath}', install_prefix)
            #os.environ['MODULEPATH'] = modpath
            #print(modpath)
            self.prerun_cmds = [f'export MODULEPATH={modpath}']

        # Load the module we are testing
        self.name_ver = '/'.join(self.mod.split('/')[-2:])[:-4]
        self.modules = [self.name_ver]

        # Execution - call executable with `--help` or `--version` option
        self.base_name = self.mod.split('/')[-2] # Extract package/library name from full module path
        version_cmds = ['fftw', 'gromacs']
        version_checks = [v in self.mod for v in version_cmds]
        if any(version_checks):
            self.base_name = self.name_ver
        self.executable = modules_dict[self.base_name][0]
        # /scratch/pawsey0001/cmeyer/setonix/2024.02/modules/zen3/gcc/12.2.0/astro-applications/log4cxx/0.12.1-c++17.lua
        # /software/setonix/2023.08/software/linux-sles15-zen3/gcc-12.2.0/log4cxx-0.12.1-tts6e2oycymkrykrtw6gb4xg7lpyfa6w/lib64/liblog4cxx.so
        if self.executable == 'ldd':
            #print(self.mod)
            lib_path = get_library_path(self.mod.split('/')[-2:])
            self.executable_opts = [lib_path + '/' + modules_dict[self.base_name][1]]
        else:
            self.executable_opts = [modules_dict[self.base_name][1]]
        # if self.executable == 'ldd':
        #     software_path = 
        #     /software/setonix/2023.08/software/linux-sles15-zen3/gcc-12.2.0/cfitsio-4.1.0-n4hb72skl7nj2iodnbjzluizv7pamanr/lib/libcfitsio.so
        # else:
        

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
            if len(modules_dict[self.base_name]) > 3:
                return sn.assert_found(modules_dict[self.base_name][2], self.stderr)
            else:
                return sn.assert_found(modules_dict[self.base_name][2], self.stdout)
