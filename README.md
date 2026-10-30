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

You will need to ask the platforms team to apply root permissions to Singularity ss soon as it is installed. The script to run as root is found in the `bin` directory within the spack installation prefix.

#### Updating Singularity modulefiles without reinstalling

Use [scripts/update_singularity_modules.sh](scripts/update_singularity_modules.sh)
to render the **current checkout's template, including uncommitted changes**, for
an already installed SingularityCE. It uses the existing Spack 1.1.1 installation
and repository variant generator; it does not install or concretize software,
change package privileges, or overwrite the installed template.

Installation and updating share
[scripts/singularity_module_pipeline.sh](scripts/singularity_module_pipeline.sh).
It prepares the checkout's templates/module configuration, expands stack paths,
selects installed specs, renders their Spack modules, and calls the existing
Pawsey variant generator. Both installation entry points call
[scripts/generate_singularity_modules.sh](scripts/generate_singularity_modules.sh),
which runs this pipeline for all installed SingularityCE versions matching the
configured architecture/compiler. The updater runs it for one required version
in a private tree, then handles validation, labels, and safe deployment.
Installation generation logs are retained under
`$INSTALL_PREFIX/module-generation-runs/`.

The Spack installer also uses the shared input-preparation/path-expansion
functions. Changes to template preparation, rendering, or variant generation
belong in this shared pipeline, not in a second updater implementation. This
shares generation logic, not concrete dependencies: equivalence assumes the
same installed specs, Spack, configuration, templates, and runtime helpers.
Spack API/layout changes can still require changes to the shared pipeline.

The pre-refactor updater is preserved as
[scripts/update_singularity_modules.sh.prototype01](scripts/update_singularity_modules.sh.prototype01)
for reference; it is a frozen snapshot, not another maintained entry point.

```bash
bash scripts/update_singularity_modules.sh --date-tag 2026.09 --version 4.3.5
```

The base version is configured as `singularityce_version` in
`systems/setonix/settings.sh`. The `-nompi` and `-mpi` module versions are derived
from it for other stack scripts. The updater has **no default version**:
`--version VERSION` is mandatory on every invocation, including restore.
The selected version must already be installed in the target stack for generation.

Use `--suffix recreated` to name the generated variants, for example,
`singularity/4.3.5-mpi-recreated`. The generated Spack source module is also
labelled (`4.3.5-recreated.lua`); the installed package version is unchanged.
This works with staging, `--replace-in-test`, and `--apply-live`. Publication
leaves unlabelled modulefiles untouched; repeated publication with the same
suffix backs up the existing labelled files. Restore requires the same
`--suffix` to select that labelled history. Labels must start with a
letter or digit and contain only letters, digits, underscores, or hyphens.

By default, each run writes only into a new directory below
`$MYSCRATCH/singularity-module-updates/<date-tag>`. The script reads the checkout's
Setonix settings and site/staff module configuration, selects one installed spec
for its configured architecture and GCC, and syntax-checks the resulting source
and variant modulefiles. It also checks each staged variant with Lmod and records
the installed spec hash, repository revision/dirty state, input checksums, logs,
and a diff against live modules. The printed `module use` command exposes the
candidates for further testing; first unload an already-loaded `singularity`
module so it cannot mask the candidate. The script does not run an MPI/container
workload.

Only `--apply-live` publishes the validated modules for that version. It backs up
the Spack source module and all affected Pawsey variants to hidden names such as
`.4.3.5-mpi.lua.<UTC-timestamp>-<unique-id>.bak` alongside the originals. Unselected
versions, installed templates, shared Lmod helpers, and software remain unchanged.
Live directories must already exist and be writable. Cooperating updater runs
are locked out; each file replacement is atomic, but the whole set is not.
Failed deployment attempts automatic rollback. After a successful deployment
(or a hard interruption), use the printed restore command:

```bash
bash scripts/update_singularity_modules.sh --date-tag 2026.09 \
  --version 4.3.5 --apply-live --restore
```

`--restore` takes no value. It undoes the latest outstanding replacement matching
the destination, version, and suffix, and reports how many earlier replacements
remain. Repeat the same command to undo one more replacement at a time.
It retains backups and refuses to overwrite files changed since deployment or
use damaged backups; it never skips a conflicting latest replacement.
If no matching history remains, it reports an error without changing modules.
Use `--restore --force` to undo a replacement despite subsequent manual edits.
Before undoing it, changed current files are preserved beside the modules as
`.<filename>.before-restore.<UTC-timestamp>-<unique-id>.bak`. Force does not bypass
original-backup validation or symlink protection.

Use `--repair` instead of `--restore` to recover the exact saved contents of the
latest active deployment, without undoing it or regenerating from current
templates. Use the same destination, version, and suffix as publication.
Repair validates all saved candidates against deployment checksums before making
changes. Edited current files are preserved beside the modules as
`.<filename>.before-repair.<UTC-timestamp>-<unique-id>.bak`; missing files are
recreated and unchanged files are left alone. Backup paths are printed, and a
preservation manifest is retained inside the deployment run. Failed repair
attempts rollback to the pre-repair files. Successful repair leaves deployment
history unchanged. Interrupted deployments must be restored, not repaired.
`--repair` and `--restore` cannot be combined; `--force` is only for restore.

Keep the run directories and hidden backups until testing is complete.
New deployments register their run paths in a hidden destination history index,
so runs created with a custom `--prefix` are also discoverable. Legacy deployments
are discovered below the default staging parent; for older custom locations,
pass the same `--prefix` when restoring.
Do not run the script with sudo. See `--help` for alternate existing stack and
staging locations.

To exercise the same replacement and backup logic without touching live
modules, pass `--replace-in-test` with the run directory of an earlier staged
generation:

```bash
bash scripts/update_singularity_modules.sh \
  --version 4.3.5 \
  --replace-in-test /scratch/.../singularity-module-updates/2026.11/<earlier-run>
```

This writes fresh candidates and a deployment manifest in a new run, while
replacing only the earlier run's `tree` modulefiles. Hidden backups are created
beside those test modulefiles. The script prints a `--restore` command that
names the test target but needs no replacement-run path; use it to undo the
latest matching replacement. `--replace-in-test` and `--apply-live` cannot be
combined.

Driver safety tests use a temporary fake stack and the real variant generator:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_update_*.py'
```

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
