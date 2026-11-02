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
after installing environments. SingularityCE must already be installed in that
stack, and the configured stack Python/Lmod modules must be available. The driver
renders the current checkout's template with the installed Spack into a fresh
private staging run, then uses the existing
[`create_custom_singularity_modules_from_general_singularity_container_engine.sh`](scripts/create_custom_singularity_modules_from_general_singularity_container_engine.sh)
generator to create custom variants. The general Spack installer remains
unchanged; the SHPC-only installer checks that its configured Singularity
modules can be loaded and does not regenerate them.

The driver requires `--install-type official|testing` and `--version VERSION|all`.
A selected version (or all selected with `--version all`) must already be installed
for the configured architecture and GCC compiler. Omit `--flavour` to generate
all seven variants (`nompi`, `mpi`, `mpi-gpu`, `askap`, `askap-gpu`, `nohost`,
and `slurm`), or provide one comma-separated `--flavour` list to choose a
subset. Empty entries are rejected; duplicate valid names are generated once.
For example:

```bash
./scripts/generate_singularity_modules.sh --install-type testing \
  --stack-prefix /software/setonix/2026.11 \
  --version 4.3.5 --flavour mpi,mpi-gpu --suffix qa
```

`--date-tag`, `--stack-prefix`, and `--prefix` select the stack release, existing
stack, and staging parent. Defaults are derived from the current settings and
environment; the staging parent defaults to
`$MYSCRATCH/singularity-module-updates/<date-tag>`. The staging parent must be
strictly below `MYSCRATCH`; the existing input stack can be outside scratch,
including under `/software`. Each invocation creates a new staging run. Testing mode
validates and retains its generated files there without publishing them.
Official mode publishes only validated custom variants and helpers. `--suffix`
labels only custom variants. Spack base modules are rendered privately and
never published.

The driver validates generated Lua with `luac` and checks each selected custom
module with Lmod. It does not execute containers. It stages the two shared Lmod
helpers alongside variants; replacing a shared helper may affect every module
that loads it. Generated variants locate these helpers relative to their module
tree, so testing uses the staged helpers even before a first publication.
The Spack generation timestamp is omitted from custom variants so unchanged
content remains identical across runs. Before publishing, the driver lists every destination, reuses
identical files, and reports all differing files before writing. `--force` is
available only for official installs; it atomically replaces differences.
Symlink destinations and parent directories are rejected, and publication is
serialized under a stack-wide lock. No backups or automatic deletions are made.
Partial publication failures report exact changed paths and retain staging.

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
* `install_python.sh` installs Python using Spack. To do so, and only in this case, Spack chooses `cray-python` as interpreter. Once Python is installed for different architectures and versions, `cray-python` won't be used anymore.
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
