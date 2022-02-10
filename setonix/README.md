## Setonix setup


The `setonix/` directory contains the following:
* `configs/site_allusers/`: configuration files for Setonix that is valid for all users, which will sit in $spack/etc/spack
* `configs/spackuser_pawseystaff/`: configuration files for system-wide installs (Pawsey staff), which will sit in ~/.spack/, allowing spack user overrides of config
* `environments/`: environments for deployment on Setonix
* `fixes/`: Pawsey fixes to be applied to Spack prior to production use
* `repo_setonix/`: custom package recipes for Setonix
* `templates_setonix/`: custom templates (modulefiles, Dockerfiles)

The system-wide software stack is installed under `/software/setonix/YYYY.MM/` with the following sub-directories:
* `software/`: Spack software installations
* `modules/`: Spack modulefules
* `spack/`: Spack installation
* `pawsey-spack-config/`: this repo, including `setonix/repo_setonix` for customised package recipes

A couple of sub-directories also sit here, that are unrelated to Spack:
* `containers/`: system-wide container and container module deployments (eg bioinformatics through SHPC)
* `singularity-hpc/`: Singularity-HPC (SHPC) installation

As regards configuration YAMLs, note that Spack prioritises user configs to site configs (*i.e.* those in the Spack installation directory).  
In order to minimise edits in users' home directories, we're putting:
* user-specific settings in the site YAMLs
* system-wide settings (Pawsey staff) in the *spack* user's YAMLs


## Module categories in use

* Spack
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
* SHPC
  - `biocontainers/`  (constrained by container repo name, unless we simlink)


## To-do list (incomplete)

* Automations for updating the date tag `YYYY.MM` for full rebuilds
* Automations in case we need to update the set of module categories
* Automations for software installations
* ...


## Deployment tips

* `env_utils` needs to be installed first, as it builds `cmake`, which is otherwise set to non buildable for other environments
* `env_num_libs` needs to be installed second, as it builds otherwise non buildable *blas*, *lapack*, *scalapack* and *fftw* providers
* other environments can be built in parallel


## Usage tips

* Check spec first before install. Use `spack spec -I` to see what will be installed.
* When playing with compiler flags or compilers, use `spack spec -I` and `spack spec -I --reuse` to see if there are significant changes to the packages that will be installed. Reuse is quite good at reducing the number of dependencies that will be installed. Remember that compiler flags are propagated to dependencies, which may not be desirable. An example is debugging, where it is unlikely that debugging symbols are required for libraries.
* Beware of `spack load` as it will edit `PATH` and `LD_LIBRARY_PATH` with not just the package being loaded but all the dependencies (despite spack using rpaths). This can cause issues when running codes like gdb.


### Testing Modules

Current `modules.yaml` and the template `modulefile.lua` rely on additional features of spack found in the feature/improved-lmod-modules (https://github.com/PawseySC/spack/tree/feature/improved-lmod-modules).  
The update provides extra tokens that can be used when creating the module name and also extra keywords to the template.
