import re
import os
import yaml
import json


def get_env_vars():

    # Population dictionary with necessary environment variables, setting appropriate defaults if not set
    env_dict = {}

    env_dict['env'] = os.getenv('SPACK_ENV')
    env_dict['spack_repo_path'] = os.getenv('PAWSEY_SPACK_CONFIG_REPO')
    env_dict['install_prefix'] = os.getenv('INSTALL_PREFIX')
    env_dict['python_version'] = os.getenv('python_version')
    env_dict['gcc_version'] = os.getenv('gcc_version')
    env_dict['cce_version'] = os.getenv('cce_version')
    env_dict['system'] = os.getenv('SYSTEM') or 'setonix'

    return env_dict

def get_pkg_cmds():

    env_dict = get_env_vars()
    repo_path = env_dict['spack_repo_path']
    system = env_dict['system']

    yaml_file = f'{repo_path}/systems/{system}/rfm_files/pkg_cmds.yaml'
    with open(yaml_file, "r") as stream:
        data = yaml.safe_load(stream)
    
    return data

# Get the full set of abstract specs for an environemtn from the spack.yaml file
def get_abstract_specs():

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    system = env_dict['system']
    
    # Abstract specs we wish to install
    abstract_specs = []
    yaml_file = f'{repo_path}/systems/{system}/environments/{env}/spack.yaml'
    with open(yaml_file, "r") as stream:
        data = yaml.safe_load(stream)

    # The spec categories (in the matrices in the spack.yaml file)
    spec_categories = []
    for entry in data['spack']['specs']:
        m = entry['matrix']
        # Only add those categories which start with '$', which are expanded out
        if m[0][0][0] == '$':
            spec_categories.append(m[0][0][1:])

    # Regex pattern to pick out valid package spec definitions
    pattern = r'([\w-]+@*=*[\w.]+).*'
    for entry in data['spack']['definitions']:
        # Iterate over each group of packages
        for key, value in entry.items():
            # Select only those categories which are listed in the matrices
            if key in spec_categories:
                # Add each individual packages spec in this group
                for elem in value:
                    abstract_specs.append(elem)

    # Handle cases where specs are defined within a matrix rather than with other packages (e.g. cmake in utils env)
    for entry in data['spack']['specs']:
        for key, value in entry.items():
            if value[0][0][0] != '$':
                abstract_specs.append(value[0][0])
    
    # Sort the list and return
    return sorted(abstract_specs)

# Get spec (plus full hash) for each root package in an environment from spack.lock file
def get_root_specs():

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    system = env_dict['system']

    # Fully concretised spacks generated from concretisation
    root_specs = []
    lock_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
    with open(lock_file) as json_data:
        data = json.load(json_data)

    # Iterate over every package
    for entry in data['roots']:
        # Get full spec and hash for each package
        s = entry['spec']
        h = entry['hash']
        root_specs.append(s + ' ' + h)


    # Sort the list and return
    return sorted(root_specs)


# Get full concretised spec (plus full hash) for each spec from spack.lock file
def get_concretised_specs():

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    system = env_dict['system']

    lock_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
    with open(lock_file) as json_data:
        data = json.load(json_data)

    return data['concrete_specs']
    

# Function to process specs where part of the module path is not present in the
# concretised spec identifier, but instead is only present in the `paramaters` dictinoary 
# entry of the full dictionary of the spec in the spack.lock file
# NOTE: As of 2024.02, this is needed for xerces-c, wcslib, and boost
def special_case(pkg_name, base_spec, conc_data, pkg_hash):

    # For xerces-c the module path includes the transcoder, which is not specified in the base spec
    if pkg_name == 'xerces-c':
        new_spec = base_spec + (' ' + 'transcoder=' + conc_data['concrete_specs'][pkg_hash]['parameters']['transcoder'])
    # For wcslib, the use (or lack thereof) of cfitsio is in the module path, but not in the base spec
    elif pkg_name == 'wcslib':
        icfits = conc_data['concrete_specs'][pkg_hash]['parameters']['cfitsio']
        if icfits:
            if '+cfitsio' not in base_spec:
                new_spec = base_spec + (' ' + '+cfitsio')
        else:
            if '~cfitsio' not in base_spec:
                new_spec = base_spec + (' ' + '~cfitsio')
    elif pkg_name == 'boost':
        new_spec = base_spec + (' ' + 'visibility=' + conc_data['concrete_specs'][pkg_hash]['parameters']['visibility'])
    
    return new_spec

# Function to process projections where inclusions marked by "+" and exclusions marked by "~"
# which are included in module name are not separate by whitespace " " in spec
# NOTE: As of 2024.02, this is needed for petsc and hdf5
def process_projections(variants):

    # Modify the original list of package variants
    new_variants = variants

    # Iterate through every variant
    for v in variants:
        # If of the form "+{var}~{var}" or "~{var}+{var}" need to separate the two components, keeping the '+' and '~' symbols
        if ('+' in v) and ('~' in v):
            if v[0] == '+':
                tmp_var = v.split('~')
                tmp_var[-1] = '~' + tmp_var[-1]
            elif v[0] == '~':
                tmp_var = v.split('+')
                tmp_var[-1] = '+' + tmp_var[-1]
            new_variants = new_variants + tmp_var
        # If of the form "~{var}~{var}" or "+{var}+{var}" need to separate the two components, keeping both '~'
        elif '~' in v:
            tmp_var = v.split('~')
            tmp_var = ['~' + entry for entry in tmp_var[1:]]
            new_variants = new_variants + tmp_var
        elif '+' in v:
            tmp_var = v.split('+')
            tmp_var = ['+' + entry for entry in tmp_var[1:]]
            new_variants = new_variants + tmp_var
    
    return new_variants

# Get path to the shared object libraries for a package
def get_library_path(pkg_name_ver):

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    install_prefix = env_dict['install_prefix']
    system = env_dict['system']

    # Get root specs for this environment
    root_specs = get_root_specs()

    # Get full concrete specs for this environment
    # Since format of root spec isn't universally consistent, this makes for easier extraction of name, version, compiler, architecture, etc.
    json_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
    with open(json_file) as json_data:
        conc_data = json.load(json_data)

    # Iterate over every spec
    pkg_name = pkg_name_ver[0]
    pkg_ver = pkg_name_ver[1][:-4]
    # Handle packages with specifiers after version in module file (e.g. of the form petsc/3.19.5-complex)
    # log4cxx is treated separately since it has package version and C++ version in module file
    if ('-' in pkg_ver) and (pkg_name != 'log4cxx'): 
        pkg_ver = pkg_ver.split('-')[0]
    
    for idx, s in enumerate(root_specs):
        # Hash is last entry in spec
        h = s.split(' ')[-1]
        name = conc_data['concrete_specs'][h]['name']
        ver = conc_data['concrete_specs'][h]['version']
        if 'log4cxx' in name: # log4cxx also has the C++ version in the module path
            c_ver = conc_data['concrete_specs'][h]['parameters']['cxxstd']
            if (name == pkg_name) and (ver in pkg_ver) and (c_ver in pkg_ver):
                comp = conc_data['concrete_specs'][h]['compiler']['name'] + '-' + conc_data['concrete_specs'][h]['compiler']['version']
                arch = conc_data['concrete_specs'][h]['arch']['target']['name']
                lib_path = f'{install_prefix}/software/linux-sles15-{arch}/{comp}/{name}-{ver}-{h}'
                break
        else:
            if (name == pkg_name) and (ver == pkg_ver):
                comp = conc_data['concrete_specs'][h]['compiler']['name'] + '-' + conc_data['concrete_specs'][h]['compiler']['version']
                arch = conc_data['concrete_specs'][h]['arch']['target']['name']
                lib_path = f'{install_prefix}/software/linux-sles15-{arch}/{comp}/{name}-{ver}-{h}'
                break

    return lib_path

# Build a spec of the format of those specified in the `roots` section of the spack.lock file
def build_root_spec(conc_spec, param_dict):

    # Get package information from the full concrete spec
    name = conc_spec['name']
    ver = conc_spec['version']
    h = conc_spec['hash']
    comp_name = conc_spec['compiler']['name']
    comp_ver = conc_spec['compiler']['version']

    # Start with the basic components of the spec
    root_spec = name + '@' + ver + '%' + comp_name + '@' + comp_ver

    # Add to spec from the parameters dictionary of the concrete spec
    # Only add the True/False parameter values in the format of +param and ~param
    for key, val in param_dict.items():
        if val == False:
            root_spec += ('~' + key)
        elif val == True:
            root_spec += ('+' + key)
        elif isinstance(val, list):
            continue
        
    # Add key-value parameters from parameters dictionary of the
    # concrete spec in the format key=value
    for key, val in param_dict.items():
        if isinstance(val, list):
            continue
        if (val != False) and (val != True):
            root_spec += (' ' + key + '=' + val)
    
    # Add the hash to the end of the spec
    root_spec += (' ' + h)

    return root_spec

# Get full module path for this package
# NOTE: This is used primarily for dependencies, which are not root packages of any of the environments
def get_dependency_module_path(pkg_info, conc_specs, pkg_spec):
    # List of specs which need extra hardcoded work to match conretsied spec to full module path
    special_cases = ['xerces-c', 'wcslib', 'boost']

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    install_prefix = env_dict['install_prefix']
    system = env_dict['system']
    python_ver = env_dict['python_version']

    # Master module file describing format of full module path across all environments
    yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
    with open(yaml_file, "r") as stream:
        mod_data = yaml.safe_load(stream) 
    # Projections describe module paths for each package
    projections = mod_data['modules']['default']['lmod']['projections']
    projs = []
    paths = []
    # Fill lists with corresponding projections and paths
    for proj in projections:
        paths.append(projections[proj])
        projs.append(proj)

    # Details of dependency
    name = pkg_info['name']
    h = pkg_info['hash']
    version  = pkg_info['version']
    comp = pkg_info['compiler']['name'] + '/' + pkg_info['compiler']['version']
    arch = pkg_info['arch']['target']['name']

    # Get index of this package in the set of all concretised specs by matching hashes
    hashes = [c for c in conc_specs]
    idx = [i for i, j in enumerate(hashes) if j == h][0]

    # Find mathching projection for the spec of this package
    matching_projections = []
    for p_idx, p in enumerate(projs):
        # Split projection into list of specifiers
        specifiers = p.split(' ')
        if name in p:
            mask = ['~' not in s for s in specifiers]
            # Iterate through all variants, updating if needed
            updated_specifiers = [b for a, b in zip(mask, specifiers) if a]
            # If all specifiers of a variant are present in the package spec, it matches
            if all(s in pkg_spec for s in updated_specifiers):
                matching_projections.append(p)

    # Handle dependencies which are a partial match to a projection, but not a full match
    # These are then hidden module files in the dependencies directory
    # One example is boost/1.80.0 dependency for hpx/1.8.1 - there are explicit boost projections, 
    # but this particular boost variant does not have a matching projection,
    # so it goes under dependencies catch-all projection
    if len(matching_projections) == 0:
        full_mod_path = f'{install_prefix}/modules/{arch}/{comp}/' + paths[-1].replace('{name}', name).replace('{version}', version).replace('{hash:7}', h[:7]) + '.lua'
        return full_mod_path
        

    # There is more than one possible matching projection
    if len(matching_projections) > 1:
        nmatches = []
        for idx, proj in enumerate(matching_projections):
            # Split projection into it's components (i.e. "gromacs +double" -> ['gromacs', '+double'])
            tmp = proj.split(' ')
            # petsc and hdf5 specs structured differently to all others, needs special treatment
            if 'petsc' == matching_projections[0][0:5]:
                tmp = process_projections(tmp)
            if 'hdf5' == matching_projections[0][0:4]:
                tmp = process_projections(tmp)
            # Number of keywords in this projection which are found in the package concretised spec
            nmatches.append(sum([keyword in pkg_spec for keyword in tmp]))
        # Pick the projection which has the most keyword matches
        max_idx = max(enumerate(nmatches), key=lambda x: x[1])[0]
        matched_proj = matching_projections[max_idx]
    # There is only one matched projection
    else:
        matched_proj = matching_projections[0]


    # Get module path for the matched projection
    for p_idx, p in enumerate(projs):
        if p == matched_proj:
            # Do we need to include the python version (e.g. for mpi4py)?
            if '^python.version' in paths[p_idx]:
                matching_mod_path = paths[p_idx].replace('{name}', name).replace('{version}', version).replace('{^python.version}', python_ver)
            # Standard projection
            else:
                matching_mod_path = paths[p_idx].replace('{name}', name).replace('{version}', version)

    # Convert the matching module path into full absolute path
    full_mod_path = install_prefix + f'/modules/{arch}/{comp}/' + matching_mod_path + '.lua'

    return full_mod_path

# Get the full module paths for all dependencies for this package
def get_module_dependencies(pkg_module_path):

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    install_prefix = env_dict['install_prefix']
    system = env_dict['system']
    python_ver = env_dict['python_version']

    # Get root specs from the environment this package is in
    root_specs = get_root_specs()
    conc_specs = get_concretised_specs()

    yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
    with open(yaml_file, "r") as stream:
        mod_data = yaml.safe_load(stream)    
    # Projections describe module paths for each spec
    projections = mod_data['modules']['default']['lmod']['projections']
    projs = []
    paths = []
    # Fill lists with corresponding projections and paths
    for proj in projections:
        paths.append(projections[proj])
        projs.append(proj)
    
    # List to hold full absolute module paths for every dependency of this package
    dep_paths = []

    # Get relevant package info (name, ver, compiler, architecture) from full module path
    pkg_info = pkg_module_path[:-4].split('/')[-6:]
    if '-' in pkg_info[-1]: # Handle those modules with info between version and .lua file extension
        pkg_info = pkg_info[:-1] + [pkg_info[-1].split('-')[0]]

    # Iterate over every root spec across all environments
    for idx, s in enumerate(root_specs):
        # Hash is last entry in spec
        h = s.split(' ')[-1]
        # Get full concrete specs for this root spec
        c = conc_specs[h]
        name = c['name']
        ver = c['version']
        comp_name = c['compiler']['name']
        comp_ver = c['compiler']['version']
        arch = c['arch']['target']['name']
        # This root spec is a full match for this module
        if all(map(lambda v: v in pkg_info, [name, ver, comp_name, comp_ver, arch])):
            # Check if it has any dependencies
            key_list = [k for k in c.keys()]
            if 'dependencies' in key_list:
                deps = c['dependencies']
                # Iterate through dependencies
                for d in deps:
                    dh = d['hash']
                    dc = conc_specs[dh]
                    d_comp = dc['compiler']['name'] + '/' + dc['compiler']['version']
                    d_arch = dc['arch']['target']['name']
                    # Treat git separately
                    if dc['name'] == 'git':
                        path = f'{install_prefix}/modules/{d_arch}/{d_comp}/' + paths[-2].replace('{version}', dc['version']).replace('{hash:7}', dh[:7]) + '.lua'
                    else:
                        # See if any projections are at least a partial match to this dependency
                        nchars = len(dc['name'])
                        proj_matches = [dc['name'] == proj[0:nchars] for proj in projs]
                        if any(proj_matches):
                            # Build a "root spec" for this dependency and get its full module path
                            built_spec = build_root_spec(dc, dc['parameters'])
                            path = get_dependency_module_path(dc, conc_specs, built_spec)
                        # There is not even a partial projection match, so it falls under the dependencies catch-all projection
                        else:
                            path = f'{install_prefix}/modules/{d_arch}/{d_comp}/' + paths[-1].replace('{name}', dc['name']).replace('{version}', dc['version']).replace('{hash:7}', dh[:7]) + '.lua'
                    dep_paths.append(path)
    
    return dep_paths

# Get full absolute module paths for every package in an environment
def get_module_paths():
    # List of specs which need extra hardcoded work to match conretsied spec to full module path
    special_cases = ['xerces-c', 'wcslib', 'boost']

    # Get required environment variables
    env_dict = get_env_vars()
    env = env_dict['env']
    repo_path = env_dict['spack_repo_path']
    install_prefix = env_dict['install_prefix']
    python_ver = env_dict['python_version'] # Some python packages include python version in their name (e.g. mpi4py)
    system = env_dict['system']

    # Get root specs for this environment (from environments/{env}/spack.lock file)
    # Three lists - full concretised spec, reduced list in format {name}/{version}, and hash
    root_specs = get_root_specs()
    root_name_ver = [None] * len(root_specs)
    hashes = [None] * len(root_specs)
    arches = [None] * len(root_specs)
    compilers = [None] * len(root_specs)

    #########################################
    # Convert full spec to name and version #
    #########################################
    # File containging concrete specs
    json_file = f'{repo_path}/systems/{system}/environments/{env}/spack.lock'
    with open(json_file) as json_data:
        conc_data = json.load(json_data)

    # Given root spec is not in universally consistent format, use full concrete specs to get compilers, architecture, etc.
    for idx, s in enumerate(root_specs):
        # Hash is last entry in spec
        h = s.split(' ')[-1]
        hashes[idx] = h
        comp = conc_data['concrete_specs'][h]['compiler']['name'] + '/' + conc_data['concrete_specs'][h]['compiler']['version']
        compilers[idx] = comp
        arch = conc_data['concrete_specs'][h]['arch']['target']['name']
        arches[idx] = arch
        root_name_ver[idx] = conc_data['concrete_specs'][h]['name'] + '/' + conc_data['concrete_specs'][h]['version']


    ##################################################
    # Matching concretised specs to full module path #
    ##################################################
    # Master module file describing format of full module path across all environments
    yaml_file = f'{repo_path}/systems/{system}/configs/spackuser/modules.yaml'
    with open(yaml_file, "r") as stream:
        mod_data = yaml.safe_load(stream)    
    # Projections describe module paths for each spec
    projections = mod_data['modules']['default']['lmod']['projections']
    projs = []
    paths = []
    # Fill lists with corresponding projections and paths
    for proj in projections:
        paths.append(projections[proj])
        projs.append(proj)

    # Match each projection with the corresponding abstract spec
    matching_projections = [ [] for _ in range(len(root_specs))]
    for c_idx, c_spec in enumerate(root_specs):
        # Extract name of module from {name}/{version} entries
        name = root_name_ver[c_idx].split('/')[0]
        # Iterate through each projection
        for p_idx, p in enumerate(projs):
            # If there are variants, extra specifications will be separated from name by ' '
            # Examples: gromacs vs. gromacs +double, lammps ~rocm vs. lammps +rocm
            specifiers = p.split(' ')
            # If the name of this concretised spec is within this projection
            if name in p:
                # Handle special cases (part of module path is not in root spec, but is in concretised spec dict entry in .lock file)
                if name in special_cases:
                    updated_spec = special_case(name, c_spec, conc_data, hashes[c_idx])
                    root_specs[c_idx] = updated_spec
                # Update `c_spec` (will only differ from c_spec for special cases)
                updated_c_spec = root_specs[c_idx]
                # Filter variants, removing entries with `~` since it denotes the lack of something
                mask = ['~' not in s for s in specifiers]
                # Iterate through all specifiers, updating if needed
                updated_specifiers = [b for a, b in zip(mask, specifiers) if a]
                # If all specifiers of a projection are present in the spec, it matches
                if all(s in updated_c_spec for s in updated_specifiers):
                    matching_projections[c_idx].append(p)


    # Multiple projections can match a single spec, we need to pick the one true match
    # Example: A spec with "gromacs +double" can be matched by both "gromacs" and "gromacs +double" projections
    for m_idx, m in enumerate(matching_projections):
        # If there is more than one matching projection for this spec
        if len(m) > 1:
            # List to hold the number of keywords in each possible match that are found in the concretised spec
            # The possible match with the highest number of keyword matches is selected as the correct match
            # Example: "gromacs +double" is matched with both "gromacs" and "gromacs +double" projections
            # so "gromacs +double" has 2 matches and "gromacs" just 1, so "gromacs +double" projection is chosen
            nmatches = []
            for idx, proj in enumerate(m):
                # Split projection into it's components (i.e. "gromacs +double" -> ['gromacs', '+double'])
                tmp = proj.split(' ')
                # petsc/hdf5 specs structured differently to all others, needs special treatment
                if 'petsc' == m[0][0:5]:
                    tmp = process_projections(tmp)
                if 'hdf5' == m[0][0:4]:
                    tmp = process_projections(tmp)
                # Number of keywords in this variant which are found in the full concretised spec
                nmatches.append(sum([keyword in root_specs[m_idx] for keyword in tmp]))
            # Find projectionn with highest number of keyword matches
            max_idx = max(enumerate(nmatches), key=lambda x: x[1])[0]
            matching_projections[m_idx] = [m[max_idx]]
            
    
    # Account for dependencies (e.g. llvm) which give len(m) == 0
    # Need to update all lists to exclude dependencies
    mask = [len(m) > 0 for m in matching_projections]
    # Convert from list of lists to list of strings
    matching_projections = [m[0] for m in matching_projections if len(m) > 0]
    # Select the concretised specs that aren't dependencies using selection mask
    updated_root_name_ver = [b for a, b in zip(mask, root_name_ver) if a]
    updated_arches = [b for a, b in zip(mask, arches) if a]
    updated_compilers = [b for a, b in zip(mask, compilers) if a]

    # List to hold module paths for matched projection of each abstract spec
    matching_mod_paths = [None for _ in range(len(matching_projections))]
    for m_idx, m in enumerate(matching_projections):
        # Name and version are both included
        if '/' in updated_root_name_ver[m_idx]:
            name, ver = updated_root_name_ver[m_idx].split('/')
        # No version information in the spec, need to search spec dictionary entry in .lock file
        else:
            name = updated_root_name_ver[m_idx]
            cs = conc_data['concrete_specs']
            ver = cs[hashes[m_idx]]['version']
        for p_idx, p in enumerate(projs):
            # This projection matches one of the abstract specs
            if p == m:
                # Do we need to include the python version (e.g. for mpi4py)?
                if '^python.version' in paths[p_idx]:
                    matching_mod_paths[m_idx] = paths[p_idx].replace('{name}', name).replace('{version}', ver).replace('{^python.version}', python_ver)
                # Standard projection
                else:
                    matching_mod_paths[m_idx] = paths[p_idx].replace('{name}', name).replace('{version}', ver)

    # Convert the matching module paths into full absolute paths
    full_mod_paths = [None] * len(matching_mod_paths)
    for i in range(len(matching_mod_paths)):
        compiler = 'cce/' + env_dict['cce_version'] if 'cce' in updated_compilers[i] else 'gcc/' + env_dict['gcc_version']
        arch = updated_arches[i]
        full_mod_paths[i] = install_prefix + f'/modules/{arch}/{compiler}/' + matching_mod_paths[i] + '.lua'

    return full_mod_paths