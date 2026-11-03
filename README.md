# Pawsey Spack Configuration

Scripts and configuration files used by the Pawsey Supercomputing Research Centre to deploy Spack and to install the scientific software stack on its supercomputing systems.

## Installation

Here is how to launch the software stack installation.

1. Make sure the system you want to install the software stack on has a corresponding directory in `systems`. If not, you can start by creating a copy of an existing one.
2. Edit the file `systems/<system>/settings.sh` as needed.
3. Set and export the `INSTALL_PREFIX` variable to the full path of the filesystem location where you want the installation to be placed in. Note that it has to end with the same string as the one stored in the `DATE_TAG` variable, meaning that installations are versioned by installation date.
4. Set and export the `INSTALL_GROUP` variable to the linux group that is going to own the installed files.
5. Set and export the `SYSTEM` variable to the system you want to run the installation for, if it differs from the content of the `PAWSEY_CLUSTER` environment variable.
6. Run the `scripts/install_software_stack.sh` script, preferably in a Slurm job or as a process detached from the login shell to prevent the installation from being aborted in case the SSH connection were to be interrupted unexpectedly.

### Singularity

Ask the platforms team to apply the required root permissions to SingularityCE
after it is installed; the script to run as root is in the Spack installation's
`bin` directory.

The full-stack installer runs
[`scripts/generate_singularity_modules.sh`](scripts/generate_singularity_modules.sh)
after installing environments. SingularityCE must already be installed in the
selected stack. The script uses the installed Spack configuration and the
[`modulefile.lua`](systems/setonix/templates/modules/modulefile.lua) template to
render private base modulefiles, then calls
[`create_custom_singularity_modules_from_general_singularity_container_engine.sh`](scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh)
to generate the requested custom Singularity flavours. Private Spack base modulefiles are
never published.

The generator can also be run independently after installation to regenerate,
validate, and publish customized Singularity modulefiles without repeating the
complete software-stack installation. This supports later modulefile changes,
such as adding a new library-injection pattern to one or more flavours.

Use `--install-type testing` to validate and retain staged artifacts without
modifying the installed stack. Use `--install-type official` to publish validated
variants and the shared BASH_ENV compatibility patch files. These patch files are
shared by installed Singularity modules, so force-replacing them may affect
modules outside the versions selected in the current run.

Run the following command for the complete option reference, prerequisites,
examples, validation scope, staging details, and publication behavior:

```bash
./scripts/generate_singularity_modules.sh --help
```

The general Spack installer remains unchanged. The SHPC-only installer verifies
that its configured Singularity modules can be loaded and does not regenerate
them.

## Repository structure

The repository is composed of the directories:

* `fixes/`: patches implemented by Pawsey staff to be applied to Spack prior to production use. They are meant to improve usability of Spack for Pawsey-specific use cases.
* `repo/`: custom Spack package recipes for software not yet supported by Spack or that needed modification in the build process to work on Pawsey systems.
* `shpc_registry/`: custom Singularity-HPC (SHPC) recipes to deploy containers.
* `scripts/`: BASH scripts used to automate the deployment process.
* `systems/<system>`: a directory containing configuration files specific to a system. Scripts will use these files to customise the Spack deployment and installation of the software stack.


The `scripts/install_software_stack.sh` is the top-level script that executes the installation from start to finish except licensed software, that need some manual work. Refer to this script also as documentation of the installation process.

## The `scripts` directory

This directory contains Bash scripts to deploy Spack and SHPC, install scientific software, and maintain the software stack.

### Installer entry points

Run these drivers directly or through their Slurm launchers. Component scripts normally do not need to be invoked separately.

* `install_software_stack.sh` runs the full installation, including Spack, Python, ReFrame, environments, Singularity modules, SHPC, containers, and post-installation operations.
* `install_shpc_software_stack.sh` installs SHPC and containers and runs post-installation operations, using existing Singularity modules.
* `install_cray_software_stack.sh` runs environment concretization and checks, installs Cray environments, and runs module tests and post-installation operations.
* `install_rocm_software_stack.sh` concretizes and installs the ROCm environment.

The Slurm submission scripts are examples; review their paths, releases, accounts, and reservations before use:

* `submit_job.slm` launches the full software-stack installation.
* `submit_cray_job.slm` launches the Cray installation workflow.
* `submit_shpc_job.slm` launches the SHPC installation workflow.
* `submit_rocm_job.slm` installs the ROCm environment directly using hard-coded stack settings; it does not call the ROCm driver.
* `submit_shpc_openfoam_test_job.slm` launches the private OpenFOAM installation test and forwards its command-line options.

### Installation call chains

Indented scripts are called by their parent; siblings run from top to bottom. These trees show script calls, not every command or template expansion.

```text
submit_job.slm
`-- install_software_stack.sh
    |-- install_spack.sh
    |   `-- create_system_moduletree.sh
    |-- install_python.sh
    |-- install_reframe.sh
    |-- concretize_environments.sh
    |-- run_rfm_concretization_tests.sh
    |-- install_environments.sh
    |-- generate_singularity_modules.sh
    |   `-- create_custom_singularity_modules_from_general_singularity_container_engine.sh
    |-- install_shpc.sh
    |-- install_shpc_containers.sh
    |   `-- patch_shpc_pawsey_modules.sh
    `-- post_installation_operations.sh (expanded below)

submit_shpc_job.slm
`-- install_shpc_software_stack.sh
    |-- [check existing customized Singularity modules]
    |-- install_shpc.sh
    |-- install_shpc_containers.sh
    |   `-- patch_shpc_pawsey_modules.sh
    `-- post_installation_operations.sh

submit_cray_job.slm
`-- install_cray_software_stack.sh
    |-- concretize_environments.sh
    |-- run_rfm_concretization_tests.sh
    |-- install_cray_environments.sh
    |-- run_rfm_module_tests.sh
    `-- post_installation_operations.sh

install_rocm_software_stack.sh
|-- concretize_rocm_environment.sh
`-- install_rocm_environment.sh

submit_rocm_job.slm
`-- [direct Spack concretization and installation of the ROCm environment]

submit_shpc_openfoam_test_job.slm
`-- test_install_shpc_openfoam.sh
    `-- install_shpc_containers.sh (once per selected image)
        `-- patch_shpc_pawsey_modules.sh
```

The shared post-installation chain is:

```text
post_installation_operations.sh
|-- create_system_moduletree.sh
|-- create_wrf_roms_dependency_modules.sh
|   `-- create_dependencies_metamodule.sh (for WRF and ROMS)
|-- create_hpc_python_collection_view_module.sh
|-- set_licensing_permissions.sh
|-- patch_shpc_pawsey_modules.sh
|-- cr_operations.sh (legacy; see removal candidates)
`-- run_rfm_module_tests.sh
```

### Standalone maintenance and validation

Run these for a specific task after checking their configuration and prerequisites. Some are also called by the installation drivers above.

* `generate_singularity_modules.sh` renders and validates custom Singularity modules, retaining testing output or publishing to the selected stack.
* `generate_rocm_externals.sh` generates Spack external-package configuration for the configured ROCm installations.
* `run_rfm_concretization_tests.sh` runs ReFrame concretization checks for standard environments and lists the corresponding Cray checks.
* `run_rfm_module_tests.sh` runs ReFrame installation and module checks.
* `spack_system_package_check.sh` defines functions to check system packages against a predefined list of build prerequisites on login and compute nodes; source it and invoke the required function.
* `test_install_shpc_openfoam.sh` tests OpenFOAM container installation, generated modules, wrappers, SIF links, and `blockMesh -help` in a private scratch tree.

### Internal installation machinery

Normally called by the installation drivers; run separately only for targeted maintenance or recovery after checking prerequisites.

Deployment of Spack, Python, ReFrame, and SHPC:

* `install_spack.sh` installs Spack on the system and creates the directory structure for the system-wide software stack installation.
* `install_python.sh` installs Python using Spack. To do so, and only in this case, Spack chooses `cray-python` as interpreter. Once Python is installed for different architectures and versions, `cray-python` won't be used anymore.
* `install_reframe.sh` bootstraps the Spack solver and installs ReFrame for installation checks.
* `install_shpc.sh` installs SHPC, a tool used to deploy containers.

The software and container installation scripts are:

* `concretize_environments.sh` concretizes the configured standard and Cray Spack environments.
* `install_environments.sh` installs the configured standard and Cray environments, optionally populates the build cache, and refreshes Spack modulefiles.
* `install_cray_environments.sh` installs only the configured Cray environments.
* `concretize_rocm_environment.sh` concretizes the ROCm Spack environment.
* `install_rocm_environment.sh` installs the ROCm environment and refreshes Spack modulefiles.
* `install_shpc_containers.sh` pulls the configured containers through SHPC and customizes their modules.

Module generation and post-installation operations are implemented through:

* `create_custom_singularity_modules_from_general_singularity_container_engine.sh` transforms one rendered base module into one requested Singularity flavour.
* `create_system_moduletree.sh` creates the system module-directory structure for the configured architectures, compilers, and categories.
* `create_dependencies_metamodule.sh` creates a module that loads a package's dependencies from a Spack environment.
* `create_wrf_roms_dependency_modules.sh` creates hidden dependency-set modules for WRF and ROMS.
* `create_hpc_python_collection_view_module.sh` creates a Spack view and module for the HPC Python collection when its environment definition exists.
* `patch_shpc_pawsey_modules.sh` customizes container module names, OpenFOAM modules and SIF links, and Python startup compatibility.
* `set_licensing_permissions.sh` applies group-access restrictions to configured licensed software and associated files.
* `post_installation_operations.sh` creates module directories, generates dependency and Python-view modules, applies licensing permissions and container customizations, runs historical fixes, and launches module tests.

### Supporting files

* `pawsey_fix_initial_bash.lua` sets up the BASH_ENV compatibility patch used by Singularity modules.
* `pawsey_init_bash` provides the patched Lmod Bash initialization used inside containers.
* `_fixPYTHONSTARTUP.lua` temporarily unsets `PYTHONSTARTUP` for affected container modules and restores it on unload.
* `templates/` contains scripts and modulefiles instantiated by the installation scripts.

### Candidates to be removed

Review remaining uses before deprecating or deleting:

* `create_custom_singularity_modules.sh` is the older generator for the `singularity` package, superseded in the current workflow by the SingularityCE driver and flavour generator.
* `cr_operations.sh` contains fixes from the 2024.05 deployment, including hard-coded compiler paths; it is still called by `post_installation_operations.sh`.
* `extract_module_list.sh` exports a module inventory using hard-coded release and compiler settings, currently selecting 2025.06.
* `spack_generate_migration_scripts.sh` generates user-package migration scripts using an older module-tree layout and a default source release of 2022.11; it is still copied into the installed Spack commands by `install_spack.sh`.
* `update_user_spack_installs_after_spack_update.sh` uninstalls packages built with a selected compiler and optionally rebuilds them using older Spack-output parsing; review before reuse.


## The `systems/<system>` directory

This is where system specific configurations are placed. In particular, the following items must always be present.

* `configs/` is a directory containing `yaml` configuraiton files for Spack. There are three types of configuration:
  * `site/`: Spack configuration files that are valid for all users, which will sit in `$spack/etc/spack`.
  * `project/`: Spack configuration files that are valid for project-wide installations executed by any user using the custom Spack command `spack project [...]`.
  * `spackuser/`: Spack configuration files for system-wide installation, performed by Pawsey staff using the `spack` linux user,  allowing to override the `site` settings.
* `environments/`: Spack environments to be deployed.
* `templates/`: modulefile templates for Spack.


## Notes

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


### Testing Modules

Current `modules.yaml` and the template `modulefile.lua` rely on additional features of Spack found in the feature/improved-lmod-modules (https://github.com/PawseySC/spack/tree/feature/improved-lmod-modules).
The update provides extra tokens that can be used when creating the module name and also extra keywords to the template.
These features have now been packaged in a patch, that is applied by `install_spack.sh`.
