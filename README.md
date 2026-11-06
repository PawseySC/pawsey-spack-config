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

Build-cache mirrors are declared in each system's `configs/site/mirrors.yaml`.
`SPACK_BUILDCACHE_PATH` sets the local cache path; `SPACK_POPULATE_CACHE` controls
whether installed binaries are published to it.

### Ella NVIDIA SDK

Ella starts Spack with the system GCC Toolset and Python, then concretizes and
installs the `bootstrap` environment before the application environments:
external GCC 13.3.1, the NVIDIA HPC SDK 26.1 with CUDA 13.1, CUDA-aware
Open MPI 4.1.8 with PMI2, Python 3.11.6, and ReFrame 3.12.0. The SDK and
Open MPI install under `$INSTALL_PREFIX/software`, where application
environments use them through the external declarations in Ella's
configuration. The normal stack installation script handles both fresh
installations and retries.

### Setonix-Q bootstrap

Setonix-Q uses the same bootstrap environment workflow as Ella to install
Python 3.11.6 and ReFrame 3.12.0 with its existing external GNU compiler.
NVIDIA compiler and CUDA packages continue to use the system-provided
installations.

### Installation metadata

Completed Setonix-Q and Ella deployments publish
`$INSTALL_PREFIX/installation_metadata/spack_install_manifest.json`, a plain
JSON record of the installed packages with their source environments,
installation prefixes, and module paths. It is the input to the module tests
on both systems, and the Spack environments used for the installation are
saved alongside it. The tooling is documented in
[scripts/install_manifest](scripts/install_manifest/README.md).

### Singularity

You will need to ask the platforms team to apply root permissions to Singularity ss soon as it is installed. The script to run as root is found in the `bin` directory within the spack installation prefix.

### Software stack modulefile

The platforms team will need to install the `$INSTALL_PREFIX/staff_modulefiles/pawseyenv/*lua` module such that it will be loaded before the Cray compilers. They will also need to update user account creation process, following the updated `$INSTALL_PREFIX/spack/bin/spack_create_user_moduletree.sh`.


## Repository structure

The repository is composed of the directories:

* `fixes/`: patches implemented by Pawsey staff to be applied to Spack prior to production use. They are meant to improve usability of Spack for Pawsey-specific use cases.
* `repo/`: custom Spack package recipes for software not yet supported by Spack or that needed modification in the build process to work on Pawsey systems.
* `shpc_registry/`: custom Singularity-HPC (SHPC) recipes to deploy containers.
* `scripts/`: BASH scripts used to automate the deployment process.
* `systems/<system>`: a directory containing configuration files specific to a system. Scripts will use these files to customise the Spack deployment and installation of the software stack.


The `scripts/install_software_stack.sh` is the top-level script that executes the installation from start to finish except licensed software, that need some manual work. Refer to this script also as documentation of the installation process.

## The `scripts` directory

This project makes up a build system for the scientific software stack on Pawsey supercomputers. On a high level, there are two logical compontents to it: 
one to deploy Spack and SHPC (a software package to manage containers), and the other to use the tools mentioned before to install scientific software.

The deployment of Spack and SHPC is implemented through the following executables BASH scripts within the `scripts` directory:

* `install_spack.sh` installs Spack on the system and creates the directory structure for the system-wide software stack installation.
* `install_bootstrap.sh` installs the configured bootstrap environment before the application environments.
* `install_python.sh` installs standalone Python on systems that use separate bootstrap installers.
* `install_shpc.sh` installs SHPC, a tool used to deploy containers.

The software stack deployment is implemented in these scripts instead:
* `concretize_environments.sh` runs the concretization step for all Spack environments to be installed.
* `install_environments.sh` will install all Spack environments using Spack.
* `install_shpc_containers.sh` will pull Pawsey-supported containers and install them using SHPC. 
* `post_installation_operations.sh` refreshes Lmod modulefiles for the installed software, applies permissions to licensed software, and other operations needed after the full stack deployment executed by Spack.


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
