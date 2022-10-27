## Setonix setup


### NOTE for next deployment - October/November 2022

Author: Marco.

Following an update of the SHPC installation, the `MODULEPATH`s for SHPC modules needs a once-off change, both for system-wide and user-specific installations.  
As a result, the following two steps are required, in collaboration with the Platforms team:
1. update `pawsey` module, based on the newly generated `/software/setonix/2022.XX/pawsey_load_first.lua` (done with Kevin for previous deployment);
2. update user account creation process, following the updated `/software/setonix/2022.XX/spack/bin/spack_create_user_moduletree.sh` (done with William for previous deployment).


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
2. Create appropriate host directory (e.g. `/software/setonix/2022.01`)
3. Git clone `pawsey-spack-config` in appropriate final location (e.g. `/software/setonix/2022.01/pawsey-spack-config`)
4. Setup Spack using `setup_spack.sh`
5. Install Python via Spack using `run_first_python_install.sh` (after this, the `spack` module can be used)
6. NOTE: from now on, make sure you are using the Spack version you just installed. You may need something like the following:
    ```
    module unload pawsey_prgenv
    module use /software/setonix/2022.01/pawsey_temp
    module load pawsey_temp
    ```
7. Test concretisations with `run_concretization.sh`
8. Install all Spack packages with `run_installation_all.sh`, or equivalent manual operations.  Some notes:  
    a. `env_num_libs` must be amongst the first ones, because it builds otherwise non-buildable packages;  
    b. some environments will need to be re-run with `-j 1` (`run_installation_pick.sh` can be used to this end);  
    c. make sure `env_apps` has symlinks to the tarballs for licensed software (Vasp and so on);  
9.  After `singularity` is installed:  
    a. create its customised modules using the small script `update_singularity_pawsey_modules.sh`  
    b. install `shpc` with `setup_shpc.sh`  
    c. ask platform staff with `root` rights to run the script `spack_perms_fix.sh` within the `singularity` installation  
10. After `singularity` and `shpc` are both installed, install container modules with `run_install_shpc_container_modules.sh`
11. Perform a set of post-installation tasks by running the interactive script `post_refresh_modules.sh`:  
    a. refresh Spack modules  
    b. create missing module directories  
    c. update (again) Singularity modules  
    d. refresh wrf/roms dependency modules  
    e. create hpc-python view and module  
    f. apply licensing permissions  
    g. refresh SHPC symlink modules  


### System-wide installation: maintenance notes (proposed)

* Adding Spack packages
  1. add package to appropriate environment
  2. install with `run_installation_pick.sh`
  3. refresh modules with Spack CLI (avoid using `post_refresh_modules.sh`, which currently deletes and re-creates the whole tree)

* Adding SHPC container modules
  1. add container package to `list_shpc_container_modules.sh`
  2. install with `run_install_shpc_container_modules.sh`
  3. customise SHPC modules with `post_customise_shpc_pawsey_modules.sh` (only for Pawsey modules)

* Updating Spack configuration files
  1. edit configuration in appropriate branch of `pawsey-spack-config`
  2. update Spack deployment using the script `update_spack_configs_from_pawseyspackconfig.sh`

