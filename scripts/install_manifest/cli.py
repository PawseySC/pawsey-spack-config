#!/usr/bin/env python3
"""Manage a deployment inventory and public modules from Spack environments."""

import argparse
import datetime
import fcntl
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from install_manifest import MANIFEST_FILE, SCHEMA_VERSION, atomic_write, require, source_digest, validate


def invalidate(output):
    output = Path(output)
    if output.exists():
        os.replace(output, output.with_suffix(".previous.json"))


def pending(manifest):
    """Keep registered inputs while setting aside observed installation data."""
    require(manifest.get("status") in ("pending", "complete"), "Manifest is not published")
    result = dict(manifest, status="pending", packages={}, sources={
        name: {key: source[key] for key in ("path", "digest", "roots")}
        for name, source in manifest["sources"].items()
    })
    result.pop("generated_at", None)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("invalidate", "snapshot", "publish", "validate", "cleanup"))
    parser.add_argument("--install-prefix")
    parser.add_argument("--system")
    parser.add_argument("--manifest")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--environment", action="append", default=[])
    parser.add_argument("--modules-only", action="store_true", help="Publish modules without an inventory")
    parser.add_argument("--apply", action="store_true", help="Uninstall cleanup candidates (default: preview)")
    args = parser.parse_args(argv)
    try:
        require(not args.apply or args.command == "cleanup", "--apply is only valid for cleanup")
        require(not args.modules_only or args.command == "publish",
                "--modules-only is only valid for publish")
        output = args.manifest or os.getenv("SPACK_INSTALL_MANIFEST")
        if args.command == "cleanup":
            require(output, "cleanup requires --manifest or SPACK_INSTALL_MANIFEST")
            with open(output) as stream:
                initial = validate(json.load(stream), args.system, args.install_prefix, args.environment)
            prefix = Path(initial["install_prefix"]).absolute()
        else:
            args.install_prefix = args.install_prefix or os.getenv("INSTALL_PREFIX")
            args.system = args.system or os.getenv("SYSTEM")
            require(args.install_prefix, "--install-prefix or INSTALL_PREFIX is required")
            prefix = Path(args.install_prefix).absolute()
        root = prefix / "installation_metadata"
        root.mkdir(parents=True, exist_ok=True)
        output = Path(output or root / MANIFEST_FILE)
        # All metadata mutations and module publication share one lock.
        with (root / ".manifest.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.command == "invalidate":
                invalidate(output)
                return 0
            if args.command == "validate":
                with output.open() as stream:
                    validate(json.load(stream), args.system, prefix, args.environment, published=False)
                print(output)
                return 0
            from install_manifest import spack_adapter as spack
            if args.command == "cleanup":
                with output.open() as stream:
                    manifest = validate(json.load(stream), args.system or initial["system"],
                                        prefix, args.environment)
                spack.check_cleanup_store(prefix)
                candidates = spack.cleanup_candidates(manifest, prefix)
                if not candidates:
                    print("No packages to clean up")
                    return 0
                print("Cleanup candidates:", flush=True)
                for spec in candidates:
                    print("/{} {}@{} {}".format(spec.dag_hash(), spec.name, spec.version, spec.prefix))
                if args.apply:
                    sys.stdout.flush()
                    spack.uninstall(candidates)
                else:
                    print("Preview only; rerun with --apply to uninstall these packages")
                return 0

            require(args.system, args.command + " requires --system or SYSTEM")
            if output.exists():
                with output.open() as stream:
                    manifest = json.load(stream)
            else:
                require(args.command == "snapshot", "No registered environments; run snapshot first")
                manifest = {"schema_version": SCHEMA_VERSION, "status": "pending",
                            "system": args.system, "install_prefix": str(prefix),
                            "sources": {}, "packages": {}}
            draft = pending(manifest)
            categories = os.environ.get("module_cat_list", "").split()
            require(categories, "module_cat_list must list the categories exposed in MODULEPATH")
            if args.command == "snapshot":
                require(args.source, "snapshot requires --source")
                name = args.source.absolute().name
                destination = root / "environments" / name
                require(args.source.resolve() != destination.resolve(),
                        "Snapshot source must be outside its destination")
                # Replacing one source may repair its stale inputs; all other
                # registrations must still match their saved fingerprints.
                draft["sources"].pop(name, None)
                validate(draft, args.system, prefix, published=False)
                paths = [source["path"] for source in draft["sources"].values()] + [args.source]
                specs, public, sources = spack.collect(paths)
                spack.check_prefixes(specs)
                spack.check_modules(specs, public, categories)
                if manifest["status"] == "complete":
                    invalidate(output)
                # A failed clone must never leave a published inventory in use.
                draft["sources"][name] = {"path": str(destination), "digest": None,
                                          "roots": sources[name]["roots"]}
                atomic_write(output, draft)
                spack.snapshot(args.source, destination)
                require(source_digest(args.source) == sources[name]["digest"],
                        "Snapshot source changed while saving: " + name)
                _, _, saved = spack.collect([destination])
                draft["sources"][name] = {key: saved[name][key] for key in ("path", "digest", "roots")}
                validate(draft, args.system, prefix, published=False)
                atomic_write(output, draft)
                print(destination)
                return 0

            # Normal publication always uses the registered set. An explicit
            # selection asserts that set; bootstrap modules may use a subset.
            validate(draft, args.system, prefix,
                     () if args.modules_only else args.environment, published=False)
            names = args.environment if args.modules_only and args.environment else list(draft["sources"])
            require(names, "No registered environments; run snapshot first")
            require(set(names) <= set(draft["sources"]), "Manifest is missing requested environments")
            specs, public, sources = spack.collect([draft["sources"][name]["path"] for name in names])
            require(all(source["digest"] == draft["sources"][name]["digest"]
                        for name, source in sources.items()), "An environment changed before publication")
            if manifest["status"] == "complete":
                invalidate(output)
            atomic_write(output, draft)
            sources, packages = spack.publish(specs, public, sources, categories, prefix)
            complete = {
                "schema_version": SCHEMA_VERSION, "status": "complete",
                "system": args.system, "install_prefix": str(prefix),
                "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "sources": sources, "packages": packages,
            }
            validate(complete, args.system, prefix)
            validate(draft, args.system, prefix, published=False)
            if args.modules_only:
                print("Generated modules without publishing an inventory")
            else:
                atomic_write(output, complete)
                print(output)
        return 0
    except (OSError, ValueError) as error:
        print("error: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
