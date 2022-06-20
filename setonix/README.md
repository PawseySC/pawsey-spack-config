## Setonix setup


### Contents of this directory

* `configs/site_allusers/`: Spack configuration files for Setonix that are valid for all users, which will sit in $spack/etc/spack
* `configs/spackuser_pawseystaff/`: Spack configuration files for system-wide installs (Pawsey staff), which will sit in ~/.spack/, allowing spack user overrides of config
* `configs/project_allusers/`: Spack configuration files that are valid for project-wide installations by all users (used by the dedicated script spack_project.sh)
* `custom_installs/`: custom installation scripts (for packages yet without Spack recipe)
* `environments/`: Spack environments for deployment on Setonix
* `fixes/`: Pawsey fixes to be applied to Spack prior to production use
* `repo/`: custom Spack package recipes for Setonix
* `setup_scripts/`: files for system-wide installation (scripts and custom modulefiles)
* `shpc_registry/`: custom Singularity-HPC (SHPC) recipes for Pawsey (non-Spack related)
* `templates/`: custom Spack templates (modulefiles, Dockerfiles)


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
* `pawsey-spack-config/`: this repo, including `setonix/repo/` for customised package recipes

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
  - **NOTE**: if updating list, still need to manually update `templates/modules/modulefile.lua`
  - `astro-applications`
  - `bio-applications`
  - `applications`
  - `libraries`
  - `programming-languages`
  - `utilities`
  - `visualisation`
  - `python-packages`
  - `benchmarking`
  - `developer-tools`
  - `dependencies`
* Pawsey custom builds (with compiler/arch tree)
  - `custom/modules`
* Pawsey utilities (without compiler/arch tree: Spack, SHPC, utility scripts)
  - `pawsey/modules`
* SHPC containers modules (without compiler/arch tree)
  - `containers/modules`


### Deployment tips

* install `python` first, so you can use it as the Python interpreter for Spack itself
* `env_num_libs` needs to be installed amongst the first ones, as it builds otherwise non buildable packages (only *fftw* at the moment)
* other environments can be built in parallel


### Usage tips

* Check spec first before install. Use `spack spec -I` to see what will be installed.
* When playing with compiler flags or compilers, use `spack spec -I` and `spack spec -I --reuse` to see if there are significant changes to the packages that will be installed. Reuse is quite good at reducing the number of dependencies that will be installed. Remember that compiler flags are propagated to dependencies, which may not be desirable. An example is debugging, where it is unlikely that debugging symbols are required for libraries.
* Beware of `spack load` as it will edit `PATH` and `LD_LIBRARY_PATH` with not just the package being loaded but all the dependencies (despite spack using rpaths). This can cause issues when running codes like gdb.


### Testing Modules

Current `modules.yaml` and the template `modulefile.lua` rely on additional features of Spack found in the feature/improved-lmod-modules (https://github.com/PawseySC/spack/tree/feature/improved-lmod-modules).  
The update provides extra tokens that can be used when creating the module name and also extra keywords to the template.  
These features have now been packaged in a patch, that is applied by `setup_spack.sh`.  


### System-wide installation: general procedure

Scripts residing in `setup_scripts/` allow for the full deployment of the system Spack.  This is the ideal list of steps that are required (minus the unexpected):

1. Review `variables.sh` for any required update (e.g. date_tag, compiler versions, tools versions)
2. Git clone `pawsey-spack-config` in appropriate final location (e.g. `/software/setonix/2022.01/pawsey-spack-config`)
3. Setup Spack using `setup_spack.sh`
4. Install Python via Spack using `run_first_python_install.sh` (after this, the `spack` module can be used)
5. Test concretisations with `run_concretization.sh`
6. Install all Spack packages with `run_installation_all.sh`, or equivalent manual operations; `env_num_libs` must be amongst the first ones, because it builds otherwise non-buildable packages; some environments will need to be re-run with `-j 1` (`run_installation_pick.sh` can be used to this end)
7. After `singularity` is installed, create its customised modules using the small script `update_singularity_pawsey_modules.sh`
8. After `singularity` is installed, install `shpc` with `setup_shpc.sh`
9. After `singularity` and `shpc` are installed, install container modules with 2x scripts, `run_install_shpc_container_modules.sh` and `run_install_shpc_openfoam.sh`
10. Perform a set of post-installation tasks by running the interactive script `post_refresh_modules.sh`  
    a. refresh Spack modules  
    b. create missing module directories  
    c. update (again) Singularity modules  
    d. create wrf/roms dependency modules  
    e. create hpc-python collection module  
    f. apply restricted permissions to licensed packages  
    g. refresh symlinks for SHPC container modules  


### System-wide installation: maintenance notes

* Adding Spack packages
  1. add package to appropriate environment
  2. install with `run_installation_pick.sh`
  3. refresh modules with Spack CLI (avoid using `post_refresh_modules.sh`, which currently deletes and re-creates the whole tree)

* Adding SHPC container modules - not OpenFoam
  1. add container package to either `list_shpc_container_modules.sh`
  2. install with `run_install_shpc_container_modules.sh`
  3. refresh SHPC modules with `post_create_shpc_symlink_modules.sh`

* Adding SHPC OpenFoam[-org] container modules
  1. add version-specific recipe file with version-specific command aliases onto `shpc_registry/quay.io/pawsey/openfoam[-org]/`
  2. add container package to list within `run_install_shpc_openfoam.sh`
  3. install with `run_install_shpc_openfoam.sh` itself
  4. refresh SHPC modules with `post_create_shpc_symlink_modules.sh`

* Updating Spack configuration files
  1. edit configuration in appropriate branch of `pawsey-spack-config`
  2. update Spack deployment using the script `update_spack_configs_from_pawseyspackconfig.sh`

