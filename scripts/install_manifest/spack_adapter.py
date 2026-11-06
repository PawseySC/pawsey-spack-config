"""Spack 1.1 adapter: native environments, database records, and Lmod policy."""

from collections import Counter
from contextlib import ExitStack
from pathlib import Path
import argparse
import shutil

import spack.cmd.uninstall
import spack.environment as ev
import spack.error
import spack.modules
import spack.modules.lmod
import spack.store

from install_manifest import require, source_digest


def read_environment(path):
    environment = ev.Environment(str(path))
    pairs = list(environment.concretized_specs())
    require(environment.user_specs and
            Counter(str(spec) for spec in environment.user_specs) ==
            Counter(str(abstract) for abstract, _ in pairs),
            "Environment is not completely concretized: " + str(path))
    require(all(spec.concrete for _, spec in pairs),
            "Environment contains abstract roots: " + str(path))
    return environment


def snapshot(source, destination):
    """Let Spack create the saved environment at its final path."""
    source, destination = Path(source).absolute(), Path(destination).absolute()
    require(source.resolve() != destination.resolve(), "Snapshot source equals destination")
    read_environment(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        shutil.rmtree(destination)
    ev.create_in_dir(str(destination), init_file=str(source), with_view=False)
    read_environment(destination)


def collect(paths):
    """Union exact DAGs, retaining intended public roots and their origins."""
    specs, public, sources = {}, {}, {}
    for path in paths:
        path = Path(path).absolute()
        name = path.name
        require(name not in sources, "Duplicate environment name: " + name)
        environment = read_environment(path)
        roots = environment.concrete_roots()
        sources[name] = {"path": str(path), "digest": source_digest(path),
                         "roots": sorted({spec.dag_hash() for spec in roots})}
        environment_specs = environment.all_specs()
        sources[name]["_hashes"] = {spec.dag_hash() for spec in environment_specs}
        for spec in environment_specs:
            specs[spec.dag_hash()] = spec
        for spec in roots:
            public.setdefault(spec.dag_hash(), []).append(name)
    require(public, "No public roots selected")
    return specs, public, sources


def check_prefixes(specs):
    """Protect fixed install projections, including existing DB installations."""
    owners = {}
    for spec in list(spack.store.STORE.db.query()) + list(specs.values()):
        if spec.external or spec.installed_upstream:
            continue
        prefix = str(Path(spec.prefix).resolve())
        previous = owners.setdefault(prefix, spec)
        require(previous.dag_hash() == spec.dag_hash(),
                "Installation prefix clash at {}:\n  {}\n  {}".format(prefix, previous, spec))


def visible_name(name, categories):
    category, separator, remainder = name.partition("/")
    return remainder if separator and category in categories else name


def module_metadata(spec, public, categories):
    writer = spack.modules.module_types["lmod"](spec, "default", explicit=public)
    compiler = getattr(spec, "compiler", None)
    entry = {
        "hash": spec.dag_hash(), "name": spec.name, "version": str(spec.version),
        "compiler": ({"name": compiler.name, "version": str(compiler.version)}
                     if compiler else None),
        "prefix": spec.external_path if spec.external else str(spec.prefix), "public": bool(public),
        "external": bool(spec.external), "upstream": bool(spec.installed_upstream),
        "module_path": None, "module_name": None, "scope": None, "autoloads": [],
    }
    if writer.conf.excluded:
        require(not public, "Public Lmod module is excluded: " + str(spec))
        return writer, entry
    filename = str(writer.layout.filename)
    use_name = writer.layout.use_name
    entry.update({
        "module_path": filename,
        "module_name": visible_name(use_name, categories),
        "scope": str(Path(filename).parents[len(use_name.split("/")) - 1]),
    })
    return writer, entry


def check_modules(specs, public, categories):
    """Check file paths and names exposed through category MODULEPATH entries."""
    writers, entries, paths, names = {}, {}, {}, {}
    for node_hash, spec in sorted(specs.items()):
        writer, entry = module_metadata(spec, node_hash in public, categories)
        entries[node_hash] = entry
        if entry["module_path"] is None:
            continue
        for table, key, label in (
                (paths, entry["module_path"], "module path"),
                (names, (entry["scope"], entry["module_name"]), "visible module name")):
            previous = table.setdefault(key, entry)
            require(previous["hash"] == node_hash,
                    "{} clash at {}:\n  /{} ({})\n  /{} ({})".format(
                        label, key, previous["hash"], public.get(previous["hash"], []),
                        node_hash, public.get(node_hash, [])))
        writers[node_hash] = writer
    return writers, entries


def installed_specs(specs, public):
    database = spack.store.STORE.db
    installed = {spec.dag_hash(): spec for spec in database.query(hashes=set(specs))}
    required = {}
    for node_hash in public:
        for spec in specs[node_hash].traverse(deptype=("link", "run")):
            required[spec.dag_hash()] = spec
    missing = set(required) - set(installed)
    require(not missing, "Required packages are not installed:\n" +
            "\n".join("  /{} {}".format(key, required[key]) for key in sorted(missing)))
    for spec in installed.values():
        if not spec.external or spec.external_path:
            require(Path(spec.prefix).is_dir(), "Missing installed prefix: " + str(spec.prefix))
    return installed


def check_cleanup_store(prefix):
    require(Path(prefix).resolve() in Path(spack.store.STORE.root).resolve().parents,
            "Spack store is outside the manifest installation prefix")


def cleanup_candidates(manifest, prefix):
    """Select obsolete local installs without crossing deployment boundaries."""
    require(ev.active_environment() is None, "Run cleanup through spack -E python")
    prefix = Path(prefix).resolve()
    retained = []
    for node_hash, entry in manifest["packages"].items():
        if entry["prefix"] is None:
            continue
        path = Path(entry["prefix"]).resolve()
        # Only prefixes within this deployment participate in cleanup checks.
        if path != prefix and prefix not in path.parents:
            continue
        retained.append((node_hash, path))
    candidates = []
    for spec in spack.store.STORE.db.query_local():
        if spec.external or spec.installed_upstream or spec.dag_hash() in manifest["packages"]:
            continue
        path = Path(spec.prefix).resolve()
        if prefix not in path.parents:
            continue
        # Native uninstall recomputes its deletion path from the current layout.
        require(Path(spack.store.STORE.layout.path_for_spec(spec)).resolve() == path,
                "Install layout has changed for cleanup candidate: " + str(spec.prefix))
        for keep_hash, keep in retained:
            require(not (path == keep or path in keep.parents or keep in path.parents),
                    "Cleanup candidate overlaps a retained prefix: {}\n"
                    "  retained /{}: {}".format(spec.prefix, keep_hash, keep))
        candidates.append(spec)
    return sorted(candidates, key=lambda spec: (spec.name, str(spec.version), spec.dag_hash()))


def uninstall(specs):
    """Let Spack preflight and uninstall the entire exact-hash batch."""
    if not specs:
        return
    parser = argparse.ArgumentParser()
    spack.cmd.uninstall.setup_parser(parser)
    args = parser.parse_args(["--yes-to-all", *["/" + spec.dag_hash() for spec in specs]])
    try:
        # Publication already pruned obsolete modules. Native removal computes a
        # filename without checking ownership and could remove a retained module.
        with ev.no_active_environment(), spack.modules.common.disable_modules():
            spack.cmd.uninstall.uninstall(parser, args)
    except spack.error.SpackError as error:
        raise ValueError(str(error)) from error
    except SystemExit as error:
        if error.code:
            raise ValueError("Spack refused cleanup; see its diagnostics above") from error


def publish(specs, public, sources, categories, prefix):
    check_prefixes(specs)
    # Include uninstalled concrete nodes in preflight: they can still clash if built.
    writers, entries = check_modules(specs, public, categories)
    module_roots = {writer.layout.dirname() for writer in writers.values()}
    for root in module_roots:
        require(Path(prefix).resolve() in Path(root).resolve().parents,
                "Managed module root must be inside the installation prefix: " + str(root))
    installed = installed_specs(specs, public)
    writers = {key: writer for key, writer in writers.items() if key in installed}
    entries = {key: entry for key, entry in entries.items() if key in installed}
    sources = {
        name: {"path": source["path"], "digest": source["digest"], "roots": source["roots"],
               "installed_hashes": sorted(source["_hashes"] & installed.keys())}
        for name, source in sources.items()
    }
    for node_hash, entry in entries.items():
        entry["sources"] = [name for name, source in sources.items()
                            if node_hash in source["installed_hashes"]]
    with spack.store.STORE.db.write_transaction():
        for node_hash, spec in installed.items():
            if not spec.installed_upstream:
                spack.store.STORE.db.mark(spec, "explicit", node_hash in public)
    # Nested native dependency lookups use DB explicit flags. Scope upstream
    # cache aliases to this publication; their databases must remain unchanged.
    with ExitStack() as restore:
        registry = spack.modules.lmod.configuration_registry
        for node_hash, spec in installed.items():
            if spec.installed_upstream:
                original = spack.modules.lmod.make_configuration(spec, "default")
                key = (node_hash, "default", bool(spec._installed_explicitly()))
                restore.callback(registry.__setitem__, key, original)
                registry[key] = spack.modules.lmod.make_configuration(spec, "default", node_hash in public)
        for node_hash in sorted(public):
            writer, entry = writers[node_hash], entries[node_hash]
            autoloads = []
            for dependency in writer.conf.specs_to_load:
                dep_hash = dependency.dag_hash()
                require(dep_hash in entries, "Autoload is not installed: " + str(dependency))
                autoloads.append({key: entries[dep_hash][key]
                                  for key in ("hash", "module_name", "module_path")})
            autoloads.extend({"module_name": name} for name in writer.conf.literals_to_load)
            entry["autoloads"] = autoloads

        # Spack's refresh CLI only warns about some write failures. Use its writers
        # directly so every failure prevents publication, including partial writes.
        print("Generating {} Lmod modules...".format(len(writers)), flush=True)
        module_roots = {writer.layout.dirname() for writer in writers.values()}
        for root in module_roots:
            if Path(root).exists():
                shutil.rmtree(root)
            group = [writer for writer in writers.values() if writer.layout.dirname() == root]
            spack.modules.common.generate_module_index(root, group, overwrite=True)
        for writer in writers.values():
            writer.write(overwrite=True)
        for root in module_roots:
            for path in Path(root).rglob(".modulerc.lua"):
                original = path.read_text()
                updated = original
                for category in categories:
                    updated = updated.replace('hide_version("' + category + '/', 'hide_version("')
                if original != updated:
                    path.write_text(updated)
        for entry in entries.values():
            require(entry["module_path"] is None or Path(entry["module_path"]).is_file(),
                    "Spack did not generate module: " + str(entry["module_path"]))
        require(all(source_digest(source["path"]) == source["digest"]
                    for source in sources.values()), "An environment changed during publication")
        return sources, entries
