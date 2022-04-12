## Setonix setup


### Contents of this directory

* `configs/site_allusers/`: configuration files for Setonix that is valid for all users, which will sit in $spack/etc/spack
* `configs/spackuser_pawseystaff/`: configuration files for system-wide installs (Pawsey staff), which will sit in ~/.spack/, allowing spack user overrides of config
* `environments/`: environments for deployment on Setonix
* `fixes/`: Pawsey fixes to be applied to Spack prior to production use
* `registry_setonix/`: custom Singularity-HPC (SHPC) recipes for Pawsey (non-Spack related)
* `repo_setonix/`: custom package recipes for Setonix
* `setup/`: files for system-wide installation (scripts and custom modulefiles)
* `templates_setonix/`: custom templates (modulefiles, Dockerfiles)


### Setonix software stack tree

The system-wide software stack is installed under:
```
/software/setonix/YYYY.MM
```

At every stack rebuild (every 6 months, or when needed by Cray OS updates), the latest stack will be symlinked for end users to:
```
/software/setonix/current
```

The software stack tree has the following sub-directories, related to Spack installations:
* `software/`: Spack software installations
* `modules/`: Spack modulefules
* `spack/`: Spack installation
* `pawsey-spack-config/`: this repo, including `setonix/repo_setonix` for customised package recipes

Other sub-directories also sit here, that are unrelated to Spack:
* `custom/` (those that need a compiler/arch tree)
  * `custom/software/`: Pawsey custom installations (ie manual software builds)
  * `custom/modules/`: corresponding modules
* `pawsey/` (compiler/arch independent)
  * `pawsey/software/`: Pawsey utilities (scripts, **SHPC**)
  * `pawsey/modules/`: corresponding modules (plus module for **Spack**)
* `containers/`
  * `containers/sif/`: system-wide SHPC containers (eg bioinformatics, HPC Python, OpenFoam)
  * `containers/modules/`: system-wide SHPC container modules


### Note on Spack configuration YAMLs

As regards configuration YAMLs, note that Spack prioritises user configs to site configs (*i.e.* those in the Spack installation directory).  
In order to minimise edits in users' home directories, we're putting:
* user-specific settings in the site YAMLs
* system-wide settings (Pawsey staff) in the *spack* user's YAMLs


### Module categories in use

* Spack (with compiler/arch tree)
  - `astro-applications/`
  - `bio-applications/`
  - `applications/`
  - `libraries/`
  - `programming-languages/`
  - `utilities/`
  - `visualisation/`
  - `python-packages/`
  - `benchmarking/`
  - `dependencies/`
* Pawsey custom builds (with compiler/arch tree)
  - `custom/modules/`
* Pawsey utilities (without compiler/arch tree: Spack, SHPC, utility scripts)
  - `pawsey/modules/`
* SHPC containers modules (without compiler/arch tree)
  - `containers/modules/`


### To-do list (incomplete)

* Remember to create `current` symlink: `/software/setonix/YYYY.MM` -> `/software/setonix/current`
* Compiler configuration for profiling flags
* Testing project-wide package installations
* Automations in case we need to update the set of module categories
* Automations for software installations


### Deployment tips

* `env_num_libs` needs to be installed first, as it builds otherwise non buildable packages (only *fftw* at the moment)
* other environments can be built in parallel


### Usage tips

* Check spec first before install. Use `spack spec -I` to see what will be installed.
* When playing with compiler flags or compilers, use `spack spec -I` and `spack spec -I --reuse` to see if there are significant changes to the packages that will be installed. Reuse is quite good at reducing the number of dependencies that will be installed. Remember that compiler flags are propagated to dependencies, which may not be desirable. An example is debugging, where it is unlikely that debugging symbols are required for libraries.
* Beware of `spack load` as it will edit `PATH` and `LD_LIBRARY_PATH` with not just the package being loaded but all the dependencies (despite spack using rpaths). This can cause issues when running codes like gdb.


### Testing Modules

Current `modules.yaml` and the template `modulefile.lua` rely on additional features of Spack found in the feature/improved-lmod-modules (https://github.com/PawseySC/spack/tree/feature/improved-lmod-modules).  
The update provides extra tokens that can be used when creating the module name and also extra keywords to the template.  
These features have now been packaged in a patch, that is applied by `setup_spack.sh`.  


