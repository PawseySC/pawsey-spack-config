## Topaz prototype deployment

Spack tag: `v0.17.0`


### First setup

```
# Clone the Pawsey spack repo
git clone https://github.com/pawseysc/spack
# Clone the Pawsey config repo
git clone https://github.com/pawseysc/pawsey-spack-config

# Make sure not to use .spack configs from HOME
mv ~/.spack ~/.spack_old
# Use provided configs for spack
cp pawsey-spack-config/examples/topaz/configs/*.yaml spack/etc/spack/
# Use appropriate version tag
cd spack
git checkout v0.17.0
cd ..
```

### First time Spack initialisation

```
# Load module for python 3
module load python/3.6.3

# Enable spack in shell environment
. spack/share/spack/setup-env.sh

# Try a simple spec - this will trigger the clingo bootstrap
sg pawsey0001 -c 'spack spec nano'
```

### Subsequent Spack initialisations

```
module load python/3.6.3
. spack/share/spack/setup-env.sh
```

### Config notes
- Using clingo concretiser
- Edited some service directories (builds, tarballs, ..)
- Compilers: only system gcc (4.8.5) and default gcc (8.3.0)
- Packages: CUDA aware OpenMPI, UCX, GDRcopy, CUDA, Intel MKL
- Modules: test only, will need edits for production

### Modulefile generation

```
spack module lmod refresh --delete-tree -y
```
Here we are assuming the following:
- a `modules.yaml` has been written, with the desired features
- *Lmod* is being used (for *EnvModules*, replace `lmod` with `tcl` above)
- full moduletree purge before building, to avoid silly refresh errors (good for familiarising, to turn off get rid of `--delete-tree`)

