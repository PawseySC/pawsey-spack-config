## How to use this environment file for the sprint

```
# Clone the Pawsey spack repo
git clone https://github.com/pawseysc/spack

# Clone the Pawsey config repo
git clone https://github.com/pawseysc/pawsey-spack/config

# Use provided configs for spack
cp pawsey-spack-config/examples/magnus_pascal/configs/*.yaml spack/etc/spack/
. spack/share/spack/setup-env.sh

# Use the provided template environment
cd pawsey-spack-config/examples/magnus_pascal/template_environment/

spack env create -d .
spack env activate .

# Edit the yaml to add packages

# Proposed installation tree
spack concretize

# Install
sg pawsey0001 -c spack install

## AT THE VERY END
# Clean build cache in spack/var/spack/stage
```
