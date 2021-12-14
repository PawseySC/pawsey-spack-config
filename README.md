# pawsey-spack-config

Configuration files for Spack at Pawsey.



## Setonix setup

The `setonix/` directory contains the following:
* `configs_site_allusers/`: configuration files for Setonix that is valid for all users 
* `config_spackuser_pawseystaff/`: configuration files for system-wide installs (Pawsey staff)
* `environments/`: environments for deployment on Setonix
* `repo_setonix/`: custom package recipes for Setonix
* `templates_setonix/`: custom templates

The system-wide software stack is installed under `/sofware/setonix/YYYY.MM/` with the following sub-directories:
* `software`: software installations
* `modules`: modulefules
* `spack`: Spack installation
* `pawsey-spack-config`: this repo, including `setonix/repo_setonix` for customised package recipes

As regards configuration YAMLs, note that Spack prioritises user configs to site configs (*i.e.* those in the Spack installation directory).  
In order to minimise edits in users' home directories, we're putting:
* user-specific settings in the site YAMLs
* system-wide settings (Pawsey staff) in the *spack* user's YAMLs


## Other setups

* `examples/`: deployment examples and tests
* `examples/joey_sprint/`: team sprints on Joey


## Useful tips

* check spec first before install. Use `spack spec -I` to see what will be installed. 
* When playing with compiler flags or compilers, use `spack spec -I` and `spack spec -I --reuse` to see if there are significant changes to the packages that will be installed. Reuse is quite good at reducing the number of dependencies that will be installed. Remember that compiler flags are propagated to dependencies, which may not be desirable. An example is debugging, where it is unlikely that debugging symbols are required for libraries. 
* Beware of `spack load` as it will edit `PATH` and `LD_LIBRARY_PATH` with not just the package being loaded but all the dependencies (despite spack using rpaths). This can cause issues when running codes like gdb. 

### Testing Modules

Current modules.yaml and the template rely on additional features of spack found in the feature/improved-lmod-modules (https://github.com/PawseySC/spack/tree/feature/improved-lmod-modules)
The update provides extra tokens that can be used when creating the module name and also extra keywords to the template.
