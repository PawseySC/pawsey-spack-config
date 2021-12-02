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

```
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
```
# run spec through both clingo and original for debugging 
joey_spack_debug_spec 
# save all the configs and current list of installs by spack 
joey_spack_keep_record
```

```
# Load cray-python
module load cray-python

# Enable spack in shell environment
. spack/share/spack/setup-env.sh

# Try a simple spec - this should also trigger the clingo bootstrap
spack spec nano
```


### Packages installation

```
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
