## Key commands for the setup of the next Joey sprints - 12 November 2021


**NEWS**:
- Now using tag `v0.17.0`
- Added `repos.yaml` configuration file, to use Pawsey edited recipes from `pawsey-spack-config`, when available

**NOTE**: Joey compute nodes are still unable to access the internet.  Solutions:
1. run your Spack tests on the login node (recommended for now)
2. predownload the tarballs from login node, and then build on compute nodes


### First setup

```bash
# Clone the Pawsey config repo
git clone https://github.com/pawseysc/pawsey-spack-config
cd pawsey-spack-config
cd examples/joey_sprint
# provides an easy single command to clone spack, bootstrap clingo, etc
source spack_joey_utils.sh
joey_spack_start # setup the spack environment if not present 

```

The command effectively does the following with additional verbosity to make sure setup seems correct. 

```bash
# Clone the Pawsey spack repo
git clone https://github.com/pawseysc/spack
# Clone the Pawsey config repo
git clone https://github.com/pawseysc/pawsey-spack-config

# Make sure not to use .spack configs from HOME
mv ~/.spack ~/.spack_old
# Use provided configs for spack
cp pawsey-spack-config/examples/joey_sprint/configs/*.yaml spack/etc/spack/
# Use provided json to avoid crash on compute nodes
cp pawsey-spack-config/examples/joey_sprint/fixes/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
# Use appropriate version tag
cd spack
git checkout v0.17.0
cd ..
```


### Spack setup

The spack setup can now be done with the joey_spack_start command provided in spack_joey_utils.sh
The script also provides two other commands 

```bash
# run spec through both clingo and original for debugging 
joey_spack_debug_spec 
# save all the configs and current list of installs by spack 
joey_spack_keep_record
```

```bash
# Load cray-python
module load cray-python

# Enable spack in shell environment
. spack/share/spack/setup-env.sh

# Try a simple spec - this should also trigger the clingo bootstrap
spack spec nano
```


### Packages installation

```bash
# Use the provided template environment
cd pawsey-spack-config/examples/joey_sprint/template_environment/
spack env create -d .
spack env activate .

# Edit the yaml to add packages

# Proposed installation tree
spack concretize -f
# Install
spack install -y    # -j 16

# When done with all installations, you may deactivate the Spack environment
spack env deactivate

## At the VERY END
# Make a copy of important files (environment yaml, edited recipes, logs of failed builds)
```

### Updating the Spec in Environments

Once you have settled on a build, please update the appropriate environment yaml in the `env_*` directories. For example
- if working on Reframe, create `env_utils/spack.yaml` and/or copy the yaml from the `setonix/environments/env_utils` directory and update both. 
- if working on gromacs one can do something similar with `env_apps`. 

### Checking Spack Configs

If a package is unable to build due to a missing header of a dependency, it may be beasue this dependency is an external package for which the headers have not been installed. An example was `bzip2` and `ncurses`. The compute nodes and the login of Joey may be updated with new root installed packages (as requested by the Apps team). The packages can be checked with `NodeCheck` bash function routine defined in `spack_joey_utils.sh`. Current results are found in `package_results.node.ln01.2021-12-13T23\:19-06\:00.out`

### Testing other compilers

To start with all builds should use `gcc@10.3.0`. However, if a build succeeds but the code does not perform as expect or produces segfaults, try using the gcc compiler with the debugging flags `gcc@10.3.0debug`. 

```bash
# install with debugging. First have a look at the spec
spack spec -I --reuse <package> %gcc@10.3.0
spack spec -I --reuse <package> %gcc@10.3.0debug

# then try building and running 
spack install --resuse <package> %gcc@10.3.0debug
# note the hash of the package
spack find -lv <package>
# and the load it and run it perhaps with a debugger
spack load --only package <package>/<hash>
salloc <resources>
module load gdb4hpc
srun gdb4hpc <exec> <args>
```