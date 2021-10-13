## Key commands for the setup of this Joey sprint - 13 October 2021


### Slurm interactive allocation

```
salloc -n 1 -c 16
```


### First setup

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
cp pawsey-spack-config/examples/joey_sprint/edits/microarchitectures.json spack/lib/spack/external/archspec/json/cpu/
```


### Spack setup

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
srun spack concretize -f
# Install
srun spack install -y

# When done with all installations, you may deactivate the Spack environment
spack env deactivate

## At the VERY END
# Make a copy of important files (environment yaml, edited recipes, logs of failed builds)
```
