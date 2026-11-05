# Deployment inventory

Shared tooling for Setonix-Q and Ella deployments. It saves the Spack
environments used by an installation, generates the public Lmod modules, and
publishes `$INSTALL_PREFIX/installation_metadata/spack_install_manifest.json`,
which the ReFrame module tests read.

The manifest records one entry per installed package: its source environments,
installation prefix, and module name and path when a module is generated. A
`public` flag marks the environment roots intended to have public modules.
Saved environments are fingerprinted, so a manifest is only valid while its
saved inputs are unchanged.

## Usage

The deployment scripts use the helpers in `functions.sh` (sourced by
`pawsey_software_stack_funcs.sh`); `install_software_stack.sh` runs the whole
sequence. The tool can also be run directly. Commands that need Spack must run
through `spack -E python`, and `module_cat_list` (the module categories that
pawseyenv adds to `MODULEPATH`) must be exported before snapshots or
publication.

```bash
tool="$PAWSEY_SPACK_CONFIG_REPO/scripts/install_manifest/cli.py"

python3 "$tool" invalidate
export module_cat_list
spack -E python "$tool" snapshot \
  --source "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/environments/bootstrap"
spack -E python "$tool" snapshot \
  --source "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/environments/python"
# After installing the saved environments:
spack -E python "$tool" publish
python3 "$tool" validate
```

`INSTALL_PREFIX` and `SYSTEM` can instead be passed as `--install-prefix` and
`--system`, and `--manifest` overrides the default manifest path.

* `snapshot` saves a concretized environment under
  `installation_metadata/environments/<name>` and registers it, adding to or
  replacing one entry in the registered set. The manifest stays `pending`
  until published, and snapshotting after publication sets it back to
  `pending`. If a snapshot fails, retry it: validation and publication refuse
  unfinished registrations.
* `publish` regenerates the managed module trees from all registered
  environments and writes the complete inventory. `publish --modules-only`
  generates modules for a subset (such as bootstrap) without completing the
  inventory.
* `validate` checks a manifest against the system, installation prefix, and
  saved inputs. Manifests with earlier schemas are rejected; regenerate them
  through the normal deployment flow.
* `invalidate` sets the current manifest aside as `.previous.json` and starts
  a fresh registration. To remove an environment from a deployment, invalidate
  and snapshot only the wanted environments.
* `cleanup` previews local installed packages missing from the published
  inventory; `--apply` uninstalls them. Candidates must resolve strictly beneath
  the manifest's installation prefix (`INSTALL_PREFIX`); the prefix itself,
  external and upstream packages, and paths that resolve outside it are never
  removed. Retained-prefix overlap checks use the same deployment boundary,
  including the prefix itself, so paths outside it (such as a system glibc at
  `/`) do not block cleanup.

```bash
cleanup_spack_installation "$SPACK_INSTALL_MANIFEST"
cleanup_spack_installation "$SPACK_INSTALL_MANIFEST" --apply
```

Snapshot and publication fail if two different packages would use the same
installation prefix, module file, or visible module name, if a saved
environment changes, or if the intended public roots are not fully installed.

## ReFrame

`__init__.py` is a reader that uses only the Python standard library, so the
ReFrame checks do not need to import Spack. The system checks use it to select
public modules and to verify the exact loaded module files (`_LMFILES_`) and
installation prefixes (`PAWSEY_<PACKAGE>_HOME`). The existing concretization
tests in `scripts/reframe_concretization.py` still run against the saved
environments.

The tooling is validated against Spack 1.1.1 and ReFrame 3.12.0; recheck both
interfaces when upgrading.
