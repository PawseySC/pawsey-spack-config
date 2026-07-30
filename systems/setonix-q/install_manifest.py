#!/usr/bin/env python3
"""Record concrete specs and publish Setonix-Q installation metadata."""
from __future__ import annotations

import argparse
import copy
import csv
import datetime
import json
import os
import re
import sys
import tempfile
import uuid
from contextlib import contextmanager
from pathlib import Path


SCHEMA_VERSION = 1
HASH_RE = re.compile(r"^[a-z0-9]{7,64}$")
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
RUN_FILE = "current_run.json"
CANDIDATE_FILE = "spack_install_manifest.candidate.json"
FINAL_FILE = "spack_install_manifest.json"
PLAN_FILE = "spack_install_module_plan.tsv"
SOURCE_CATEGORIES = {"standalone": "standalone", "environment": "environments"}
MEMBERSHIP_FIELDS = ("standalone", "standalone_root", "environment", "environment_root")
PLAN_FIELDS = ("hash", "name", "version", "role") + MEMBERSHIP_FIELDS


class ManifestError(RuntimeError):
    pass


def now():
    return (
        datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    )


def fail_unless(condition, message):
    if not condition:
        raise ManifestError(message)


def clean_name(value, label="name"):
    fail_unless(
        isinstance(value, str) and NAME_RE.fullmatch(value),
        f"invalid {label}: {value!r}",
    )
    return value


def clean_hash(value, label="hash"):
    fail_unless(
        isinstance(value, str) and HASH_RE.fullmatch(value),
        f"invalid {label}: {value!r}",
    )
    return value


def clean_line(value, label):
    fail_unless(
        isinstance(value, str) and value and not any(c in value for c in "\t\r\n\0"),
        f"{label} must be a non-empty single line",
    )
    return value


def absolute_path(value, label):
    clean_line(value, label)
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    return Path(os.path.normpath(path))


def metadata_root(args):
    """Resolve the installation metadata directory from CLI input or INSTALL_PREFIX."""
    value = getattr(args, "metadata_root", None)
    if not value:
        prefix = os.environ.get("INSTALL_PREFIX")
        fail_unless(prefix, "--metadata-root or INSTALL_PREFIX is required")
        value = str(Path(prefix) / "installation_metadata")
    return absolute_path(value, "metadata root")


def read_json(path, label):
    try:
        with path.open(encoding="utf-8") as stream:
            return json.load(stream)
    except FileNotFoundError as error:
        raise ManifestError(f"{label} does not exist: {path}") from error
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ManifestError(f"{label} is not valid JSON: {path}: {error}") from error


@contextmanager
def atomic_output(path):
    """Yield a stream and atomically replace the target only on success."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            yield stream
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o664)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def atomic_write(path, data):
    with atomic_output(path) as stream:
        json.dump(data, stream, indent=2, sort_keys=True)
        stream.write("\n")


def atomic_write_text(path, text):
    with atomic_output(path) as stream:
        stream.write(text)


def invalidate_assembly(root):
    """Remove the candidate manifest and module plan derived from source receipts."""
    for name in (CANDIDATE_FILE, PLAN_FILE):
        (root / name).unlink(missing_ok=True)


def load_run(root):
    """Load and validate the active Setonix-Q installation run."""
    run = read_json(root / RUN_FILE, "active installation run")
    fail_unless(
        run.get("schema_version") == SCHEMA_VERSION,
        "unsupported installation run schema",
    )
    fail_unless(
        run.get("system") == "setonix-q", "installation run is not for setonix-q"
    )
    fail_unless(isinstance(run.get("run_id"), str), "installation run has no run_id")
    return run


def receipt_path(root, kind, name):
    directory = SOURCE_CATEGORIES.get(kind)
    fail_unless(directory, f"invalid source kind: {kind!r}")
    return root / "sources" / directory / f"{clean_name(name, 'source name')}.json"


def load_receipt(root, run, kind, name, complete=False):
    """Load an active-run receipt, optionally requiring a complete, non-empty source."""
    path = receipt_path(root, kind, name)
    receipt = read_json(path, f"{kind} source {name}")
    fail_unless(
        receipt.get("schema_version") == SCHEMA_VERSION,
        f"unsupported source schema: {path}",
    )
    fail_unless(
        receipt.get("run_id") == run["run_id"],
        f"source belongs to a stale installation run: {path}",
    )
    fail_unless(
        receipt.get("kind") == kind and receipt.get("name") == name,
        f"source identity mismatch: {path}",
    )
    fail_unless(
        receipt.get("status") in ("recording", "complete"),
        f"invalid source status: {path}",
    )
    fail_unless(
        isinstance(receipt.get("roots"), list), f"source has no roots list: {path}"
    )
    if complete:
        fail_unless(
            receipt["status"] == "complete" and receipt["roots"],
            f"source is not complete: {path}",
        )
    return receipt, path


def parse_spec(data, label):
    """Validate a concrete Spack spec in format 4 and index its nodes by hash."""
    fail_unless(
        isinstance(data, dict) and isinstance(data.get("spec"), dict),
        f"{label} is not a Spack spec",
    )
    spec = data["spec"]
    fail_unless(
        spec.get("_meta", {}).get("version") == 4,
        f"{label} must use Spack spec format 4",
    )
    nodes = spec.get("nodes")
    fail_unless(isinstance(nodes, list) and nodes, f"{label} contains no nodes")
    indexed = {}
    for position, node in enumerate(nodes):
        fail_unless(isinstance(node, dict), f"{label} node {position} is invalid")
        node_hash = clean_hash(node.get("hash"), f"node {position} hash")
        fail_unless(
            node_hash not in indexed, f"{label} contains duplicate hash {node_hash}"
        )
        fail_unless(
            isinstance(node.get("name"), str) and node["name"],
            f"node {node_hash} has no name",
        )
        dependencies = node.get("dependencies", [])
        fail_unless(
            isinstance(dependencies, list), f"node {node_hash} has invalid dependencies"
        )
        for dependency in dependencies:
            fail_unless(
                isinstance(dependency, dict),
                f"node {node_hash} has an invalid dependency",
            )
            clean_hash(dependency.get("hash"), f"dependency of {node_hash}")
        build_spec = node.get("build_spec")
        if build_spec is not None:
            fail_unless(
                isinstance(build_spec, dict),
                f"node {node_hash} has an invalid build_spec",
            )
            clean_hash(build_spec.get("hash"), f"build_spec of {node_hash}")
        indexed[node_hash] = node

    # Check graph references only after every node has been indexed.
    for node_hash, node in indexed.items():
        references = [item["hash"] for item in node.get("dependencies", [])]
        if node.get("build_spec"):
            references.append(node["build_spec"]["hash"])
        missing = sorted(set(references) - set(indexed))
        fail_unless(
            not missing,
            f"node {node_hash} refers to absent nodes: {', '.join(missing)}",
        )
    return nodes[0]["hash"], indexed


def load_spec(path):
    data = read_json(path, "concrete spec")
    root_hash, indexed = parse_spec(data, str(path))
    return data, root_hash, indexed


def active_hashes(indexed, root_hash, mode):
    """Return hashes installed from a root package's concrete spec in this mode."""
    result = set()
    pending = [root_hash]
    while pending:
        node_hash = pending.pop()
        if node_hash in result:
            continue
        result.add(node_hash)
        pending.extend(
            item["hash"] for item in indexed[node_hash].get("dependencies", [])
        )
    if mode == "dependencies-only":
        result.remove(root_hash)
    return result


def store_and_record(root, receipt, requested_spec, spec_data, mode):
    """Store a concrete spec and add its root package to an open receipt."""
    fail_unless(
        receipt["status"] == "recording",
        "source is not open for recording",
    )
    fail_unless(
        mode in ("root", "dependencies-only"), f"unsupported install mode: {mode}"
    )
    requested_spec = clean_line(requested_spec, "requested spec")
    root_hash, indexed = parse_spec(spec_data, "concrete spec")
    root_node = indexed[root_hash]

    # Concrete spec files are immutable and shared between source receipts by
    # root package hash.
    stored = root / "concrete_specs" / f"{root_hash}.json"
    if stored.exists():
        fail_unless(
            read_json(stored, "stored concrete spec") == spec_data,
            f"conflicting concrete spec for {root_hash}",
        )
    else:
        atomic_write(stored, spec_data)
    record = {
        "requested_spec": requested_spec,
        "hash": root_hash,
        "name": root_node["name"],
        "version": root_node.get("version"),
        "install_mode": mode,
        "installed": mode == "root",
        "spec_file": stored.relative_to(root).as_posix(),
    }

    # Re-recording an identical root package is harmless; conflicting records are not.
    key = (requested_spec, root_hash, mode)
    existing = next(
        (
            item
            for item in receipt["roots"]
            if (item["requested_spec"], item["hash"], item["install_mode"]) == key
        ),
        None,
    )
    if existing is None:
        receipt["roots"].append(record)
        receipt["roots"].sort(
            key=lambda item: (
                item["requested_spec"],
                item["hash"],
                item["install_mode"],
            )
        )
        receipt["updated_at"] = now()
    else:
        fail_unless(
            existing == record, f"conflicting source record for {requested_spec}"
        )
    return root_hash


def load_lockfile(path):
    """Load and validate the supported Spack lockfile structure."""
    lock = read_json(path, "Spack lockfile")
    meta = lock.get("_meta", {}) if isinstance(lock, dict) else {}
    fail_unless(
        meta.get("lockfile-version") == 5 and meta.get("specfile-version") == 4,
        "Spack lockfile must use lockfile version 5 and spec format 4",
    )
    roots = lock.get("roots")
    specs = lock.get("concrete_specs")
    fail_unless(
        isinstance(roots, list) and isinstance(specs, dict),
        "Spack lockfile has invalid roots or concrete_specs",
    )
    for node_hash, node in specs.items():
        clean_hash(node_hash, "lockfile spec key")
        fail_unless(
            isinstance(node, dict) and node.get("hash") == node_hash,
            f"lockfile spec mismatch for {node_hash}",
        )
    return lock


def export_lock_root(lock, root_hash):
    """Export one lockfile root package and its graph as a format-4 concrete spec."""
    indexed = lock["concrete_specs"]
    ordered = []
    seen = set()

    def visit(node_hash):
        fail_unless(node_hash in indexed, f"lockfile refers to absent node {node_hash}")
        if node_hash in seen:
            return
        seen.add(node_hash)
        node = indexed[node_hash]
        ordered.append(copy.deepcopy(node))
        for dependency in node.get("dependencies", []):
            visit(dependency["hash"])
        if node.get("build_spec"):
            visit(node["build_spec"]["hash"])

    visit(root_hash)
    document = {"spec": {"_meta": {"version": 4}, "nodes": ordered}}
    parsed_root, _ = parse_spec(document, f"lockfile root {root_hash}")
    fail_unless(
        parsed_root == root_hash, f"exported lockfile root changed from {root_hash}"
    )
    return document


def command_init(args):
    """Start an installation metadata run after preserving the published manifest."""
    root = metadata_root(args)
    prefix = absolute_path(args.install_prefix, "install prefix")
    fail_unless(
        args.system == "setonix-q",
        "the installation manifest is currently supported only for setonix-q",
    )
    fail_unless(
        root == prefix / "installation_metadata",
        "metadata root must be <install-prefix>/installation_metadata",
    )
    date_tag = clean_line(args.date_tag, "date tag")
    spack_version = clean_line(args.spack_version, "Spack version")
    run_id = clean_line(args.run_id, "run ID") if args.run_id else None
    if run_id is None:
        timestamp = datetime.datetime.now(datetime.timezone.utc)
        run_id = f"{timestamp:%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:8]}"
    root.mkdir(parents=True, exist_ok=True)
    final = root / FINAL_FILE
    previous = root / "spack_install_manifest.previous.json"
    if final.exists():
        os.replace(final, previous)
    invalidate_assembly(root)
    run = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_id,
        "system": "setonix-q",
        "date_tag": date_tag,
        "install_prefix": str(prefix),
        "spack_version": spack_version,
        "created_at": now(),
    }
    atomic_write(root / RUN_FILE, run)
    print(run["run_id"])


def new_receipt(root, run, kind, name):
    """Create an unpersisted, empty source receipt for the active run."""
    path = receipt_path(root, kind, name)
    timestamp = now()
    receipt = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run["run_id"],
        "kind": kind,
        "name": clean_name(name, "source name"),
        "status": "recording",
        "created_at": timestamp,
        "updated_at": timestamp,
        "roots": [],
    }
    return receipt, path


def complete_receipt(receipt, path):
    """Seal and persist a non-empty source receipt."""
    fail_unless(receipt["roots"], f"cannot seal an empty source: {path}")
    receipt["status"] = "complete"
    receipt["completed_at"] = now()
    receipt["updated_at"] = receipt["completed_at"]
    atomic_write(path, receipt)


def command_reset_source(args):
    root = metadata_root(args)
    run = load_run(root)
    receipt, path = new_receipt(root, run, args.kind, args.name)
    atomic_write(path, receipt)
    invalidate_assembly(root)
    print(path)


def command_record_spec(args):
    root = metadata_root(args)
    run = load_run(root)
    receipt, path = load_receipt(root, run, args.kind, args.name)
    data, _, _ = load_spec(Path(args.spec_file))
    root_hash = store_and_record(
        root, receipt, args.requested_spec, data, args.install_mode
    )
    atomic_write(path, receipt)
    print(root_hash)


def command_record_lockfile(args):
    """Record every lockfile root package before replacing an environment receipt."""
    root = metadata_root(args)
    run = load_run(root)
    lock = load_lockfile(Path(args.lock_file))
    fail_unless(lock["roots"], "Spack lockfile contains no roots")
    receipt, path = new_receipt(root, run, "environment", args.name)
    for entry in lock["roots"]:
        root_hash = clean_hash(entry.get("hash"), "lockfile root hash")
        requested = clean_line(entry.get("spec"), "lockfile requested spec")
        store_and_record(
            root,
            receipt,
            requested,
            export_lock_root(lock, root_hash),
            args.install_mode,
        )
    complete_receipt(receipt, path)
    invalidate_assembly(root)
    print(path)


def command_seal_source(args):
    root = metadata_root(args)
    run = load_run(root)
    receipt, path = load_receipt(root, run, args.kind, args.name)
    if receipt["status"] == "complete":
        print(path)
        return
    complete_receipt(receipt, path)
    print(path)


def source_summary(receipt):
    return {"kind": receipt["kind"], "roots": copy.deepcopy(receipt["roots"])}


def load_source_receipts(root, run, requested_sources):
    """Load complete source receipts and prepare their candidate manifest entries."""
    sources = {category: {} for category in SOURCE_CATEGORIES.values()}
    receipts = []
    for kind, names in requested_sources.items():
        category = SOURCE_CATEGORIES[kind]
        for name in names:
            receipt, _ = load_receipt(root, run, kind, name, complete=True)
            sources[category][name] = source_summary(receipt)
            receipts.append(receipt)
    return sources, receipts


def module_dependency_hashes(node):
    """Return link/run or untyped dependencies used for Lmod modulefile autoloads."""
    result = []
    for dependency in node.get("dependencies", []):
        types = dependency.get("type")
        if types is None:
            types = dependency.get("parameters", {}).get("deptypes", [])
        if not types or {"link", "run"}.intersection(types):
            result.append(dependency["hash"])
    return sorted(result)


def write_module_plan(path, specs, installed_hashes, membership):
    lines = ["\t".join(PLAN_FIELDS) + "\n"]
    for node_hash in sorted(installed_hashes):
        spec = specs[node_hash]
        values = (
            node_hash,
            spec["name"],
            spec["version"],
            spec["role"],
            *(int(node_hash in membership[field]) for field in MEMBERSHIP_FIELDS),
        )
        lines.append("\t".join(map(str, values)) + "\n")
    atomic_write_text(path, "".join(lines))


def command_assemble(args):
    """Assemble source receipts into a candidate manifest and module plan."""
    root = metadata_root(args)
    run = load_run(root)
    requested_sources = {
        "standalone": sorted(set(args.standalone)),
        "environment": sorted(set(args.environment)),
    }
    fail_unless(
        any(requested_sources.values()), "assemble requires at least one source"
    )
    sources, receipts = load_source_receipts(root, run, requested_sources)

    # Merge concrete spec graphs while retaining raw nodes and source membership.
    nodes = {}
    raw_nodes = {}
    membership = {field: set() for field in MEMBERSHIP_FIELDS}
    for receipt in receipts:
        kind = receipt["kind"]
        category = SOURCE_CATEGORIES[kind]
        source_hashes = set()
        for record in receipt["roots"]:
            spec_path = root / record["spec_file"]
            _, root_hash, indexed = load_spec(spec_path)
            fail_unless(
                root_hash == record["hash"], f"source root does not match {spec_path}"
            )
            selected = active_hashes(indexed, root_hash, record["install_mode"])
            source_hashes.update(selected)
            if record["installed"]:
                membership[f"{kind}_root"].add(root_hash)

            # Compare full dependency lists before filtering to load-relevant
            # modulefile dependencies below.
            for node_hash in selected | {root_hash}:
                node = indexed[node_hash]
                minimal = {
                    "hash": node_hash,
                    "name": node["name"],
                    "version": node.get("version"),
                    "dependencies": sorted(
                        item["hash"] for item in node.get("dependencies", [])
                    ),
                }
                fail_unless(
                    node_hash not in nodes or nodes[node_hash] == minimal,
                    f"conflicting node data for {node_hash}",
                )
                nodes[node_hash] = minimal
                raw_nodes[node_hash] = node
        sources[category][receipt["name"]]["installed_hashes"] = sorted(source_hashes)
        membership[kind].update(source_hashes)

    installed_hashes = membership["standalone"] | membership["environment"]
    public_roots = membership["standalone_root"] | membership["environment_root"]

    # Build manifest entries with dependencies used by Lmod modulefile autoloads.
    specs = {}
    for node_hash in sorted(nodes):
        entry = nodes[node_hash]
        entry["dependencies"] = module_dependency_hashes(raw_nodes[node_hash])
        installed = node_hash in installed_hashes
        entry.update(
            {
                "installed": installed,
                "role": (
                    "root"
                    if node_hash in public_roots
                    else "dependency" if installed else None
                ),
                "prefix": None,
                "module_name": None,
                "module_path": None,
            }
        )
        specs[node_hash] = entry
    candidate = {
        "schema_version": SCHEMA_VERSION,
        "status": "candidate",
        "run_id": run["run_id"],
        "system": run["system"],
        "date_tag": run["date_tag"],
        "install_prefix": run["install_prefix"],
        "spack_version": run["spack_version"],
        "sources": sources,
        "specs": specs,
    }
    validate_manifest(candidate, complete=False, check_paths=False)
    output = Path(args.output) if args.output else root / CANDIDATE_FILE
    plan = Path(args.plan) if args.plan else root / PLAN_FILE
    atomic_write(output, candidate)
    write_module_plan(plan, specs, installed_hashes, membership)
    print(output)


def validate_manifest(manifest, complete, check_paths):
    """Validate manifest structure, roles, sources, and optional paths."""
    fail_unless(
        isinstance(manifest, dict) and manifest.get("schema_version") == SCHEMA_VERSION,
        "unsupported manifest schema",
    )
    valid_status = (
        manifest.get("status") == "complete"
        if complete
        else manifest.get("status") in ("candidate", "complete")
    )
    fail_unless(valid_status, "invalid manifest status")
    fail_unless(manifest.get("system") == "setonix-q", "manifest is not for setonix-q")
    fail_unless(
        isinstance(manifest.get("sources"), dict)
        and isinstance(manifest.get("specs"), dict),
        "manifest has invalid sources or specs",
    )

    # Derive installed hashes and root package hashes from the manifest spec entries.
    specs = manifest["specs"]
    installed_specs = set()
    public_specs = set()
    for node_hash, spec in specs.items():
        clean_hash(node_hash)
        fail_unless(
            isinstance(spec, dict) and spec.get("hash") == node_hash,
            f"invalid spec {node_hash}",
        )
        fail_unless(
            spec.get("role") in ("root", "dependency", None),
            f"invalid role for {node_hash}",
        )
        fail_unless(
            isinstance(spec.get("dependencies"), list),
            f"invalid dependencies for {node_hash}",
        )
        for dependency in spec["dependencies"]:
            fail_unless(
                dependency in specs,
                f"spec {node_hash} refers to absent dependency {dependency}",
            )
        if spec.get("installed"):
            installed_specs.add(node_hash)
        if spec.get("role") == "root":
            public_specs.add(node_hash)
        if check_paths and spec.get("installed"):
            prefix = spec.get("prefix")
            module_path = spec.get("module_path")
            fail_unless(
                isinstance(prefix, str) and Path(prefix).is_dir(),
                f"prefix does not exist for {node_hash}: {prefix}",
            )
            fail_unless(
                isinstance(spec.get("module_name"), str) and spec["module_name"],
                f"module name is missing for {node_hash}",
            )
            fail_unless(
                isinstance(module_path, str) and Path(module_path).is_file(),
                f"module file does not exist for {node_hash}: {module_path}",
            )

    # Derive the same hash sets from source records for cross-checking.
    source_installed = set()
    source_roots = set()
    for category in ("standalone", "environments"):
        fail_unless(
            isinstance(manifest["sources"].get(category), dict),
            f"manifest has invalid {category} sources",
        )
        for name, source in manifest["sources"][category].items():
            clean_name(name, "source name")
            fail_unless(
                isinstance(source, dict) and isinstance(source.get("roots"), list),
                f"source {name} has no roots",
            )
            installed_hashes = source.get("installed_hashes")
            fail_unless(
                isinstance(installed_hashes, list),
                f"source {name} has no installed hashes",
            )
            source_installed.update(installed_hashes)
            for record in source["roots"]:
                fail_unless(
                    isinstance(record, dict) and record.get("hash") in specs,
                    f"source {name} refers to absent root",
                )
                if record.get("installed"):
                    source_roots.add(record["hash"])
    fail_unless(
        installed_specs == source_installed,
        "installed specs do not match source records",
    )
    fail_unless(
        public_specs == source_roots, "public roots do not match source records"
    )

    # Check every role against the root-package and installation state in sources.
    for node_hash, spec in specs.items():
        expected_role = (
            "root"
            if node_hash in source_roots
            else "dependency" if node_hash in source_installed else None
        )
        fail_unless(spec["role"] == expected_role, f"incorrect role for {node_hash}")


def read_annotations(path):
    """Read hash, prefix, Lmod name, and modulefile path annotations."""
    annotations = {}
    try:
        stream = sys.stdin if str(path) == "-" else Path(path).open(encoding="utf-8")
    except FileNotFoundError as error:
        raise ManifestError(f"annotations do not exist: {path}") from error
    try:
        for line_number, raw in enumerate(stream, 1):
            line = raw.rstrip("\r\n")
            if not line or line.startswith("#"):
                continue
            columns = line.split("\t")
            fail_unless(
                len(columns) == 4,
                f"annotation line {line_number} must have four columns",
            )
            node_hash = clean_hash(
                columns[0].lstrip("/"), f"annotation line {line_number} hash"
            )
            value = (
                str(absolute_path(columns[1], "prefix")),
                clean_line(columns[2], "module name"),
                str(absolute_path(columns[3], "module path")),
            )
            fail_unless(
                node_hash not in annotations or annotations[node_hash] == value,
                f"conflicting annotation for {node_hash}",
            )
            annotations[node_hash] = value
    finally:
        if stream is not sys.stdin:
            stream.close()
    return annotations


def command_publish(args):
    """Apply module annotations and publish the final installation manifest."""
    root = metadata_root(args)
    run = load_run(root)
    candidate_path = Path(args.candidate) if args.candidate else root / CANDIDATE_FILE
    manifest = read_json(candidate_path, "candidate manifest")
    validate_manifest(manifest, complete=False, check_paths=False)
    fail_unless(
        manifest["status"] == "candidate" and manifest["run_id"] == run["run_id"],
        "candidate is stale or already published",
    )
    annotations = read_annotations(args.annotations)
    installed = {
        node_hash for node_hash, spec in manifest["specs"].items() if spec["installed"]
    }
    fail_unless(
        set(annotations) == installed,
        "annotations must contain every installed hash exactly once",
    )
    for node_hash, (prefix, module_name, module_path) in annotations.items():
        manifest["specs"][node_hash].update(
            prefix=prefix, module_name=module_name, module_path=module_path
        )
    manifest["status"] = "complete"
    manifest["published_at"] = now()
    validate_manifest(manifest, complete=True, check_paths=True)
    paths = [manifest["specs"][item]["module_path"] for item in installed]
    fail_unless(
        len(paths) == len(set(paths)),
        "two installed specs resolve to the same module path",
    )
    output = Path(args.output) if args.output else root / FINAL_FILE
    atomic_write(output, manifest)
    print(output)


def normalise_hide_versions(module_root):
    """
    The modulefile.lua template maps
    depends_on("<module category>/<module name>/...")
    to depends_on("<module name>/...") in generated modulefiles because
    pawseyenv adds each module category to MODULEPATH.

    Spack-generated .modulerc.lua files do not use this template, so remove
    the module category from their hide_version() calls here.
    """
    categories = {
        category.strip()
        for category in os.environ.get("module_cat_list", "").splitlines()
        if category.strip()
    }
    fail_unless(
        categories,
        "module_cat_list environment variable not set or empty.",
    )

    changed = 0

    for path in Path(module_root).rglob(".modulerc.lua"):
        original = path.read_text(encoding="utf-8")
        updated = original

        for category in categories:
            updated = updated.replace(
                f'hide_version("{category}/',
                'hide_version("',
            )

        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1

    return changed


def prepare_lmod_modules(rows, hashes, spack_modules, spack_store):
    """Set explicit/implicit flags, configure Lmod writers, and reject path clashes."""
    # Resolve every hash before changing Spack's explicit/implicit database flags.
    specs = []
    for node_hash in hashes:
        _upstream, record = spack_store.STORE.db.query_by_spec_hash(node_hash)
        fail_unless(
            record is not None and record.installed,
            f"/{node_hash} is not installed in the Spack database",
        )
        fail_unless(
            record.spec.dag_hash() == node_hash,
            f"Spack database returned the wrong spec for /{node_hash}",
        )
        specs.append(record.spec)

    # Setonix-Q gives implicit modules hidden, hash-qualified names. Lmod uses
    # these flags to name dependency autoloads, so set every flag first.
    with spack_store.STORE.db.write_transaction():
        for row, spec in zip(rows, specs):
            spack_store.STORE.db.mark(spec, "explicit", row["role"] == "root")

    # Resolve modulefile metadata and path clashes before regenerating modulefiles.
    refresh_writers = []
    annotations = []
    module_paths = {}
    module_root = None
    for row, node_hash, spec in zip(rows, hashes, specs):
        try:
            # The manifest role selects a readable root-package path or a hidden,
            # hash-qualified dependency path, avoiding cross-environment clashes.
            writer = spack_modules.module_types["lmod"](
                spec, "default", explicit=row["role"] == "root"
            )
            prefix = str(writer.spec.prefix)
            module_name = writer.layout.use_name
            module_path = writer.layout.filename
            module_root = module_root or writer.layout.dirname()
        except Exception as error:
            raise ManifestError(
                f"could not configure the Lmod module for /{node_hash}: {error}"
            ) from error
        fail_unless(
            not writer.conf.excluded, f"Lmod module is excluded for /{node_hash}"
        )
        fail_unless(
            prefix and Path(prefix).is_dir(),
            f"invalid prefix for /{node_hash}: {prefix}",
        )
        fail_unless(module_name, f"no Lmod name for /{node_hash}")
        annotations.append((node_hash, prefix, module_name, module_path))
        module_paths.setdefault(module_path, []).append(node_hash)

        # Standalone modulefiles already exist. Refresh modulefiles supplied only
        # by an environment, plus environment root packages promoted from
        # standalone dependencies.
        if row["environment"] == "1" and (
            row["standalone"] == "0"
            or (row["environment_root"] == "1" and row["standalone_root"] == "0")
        ):
            refresh_writers.append(writer)

    clashes = {path: values for path, values in module_paths.items() if len(values) > 1}
    fail_unless(
        not clashes,
        "module plan resolves multiple specs to the same path:\n"
        + "\n".join(
            f"  {path}: {', '.join(values)}" for path, values in clashes.items()
        ),
    )
    return refresh_writers, module_root, annotations


def command_annotate_modules(args):
    """Regenerate required Lmod modulefiles and record their manifest annotations."""
    try:
        from spack import modules as spack_modules
        from spack import store as spack_store
    except ImportError as error:
        raise ManifestError(
            "annotate-modules must be run with 'spack python'"
        ) from error

    fail_unless(args.progress_every > 0, "progress interval must be positive")
    plan_path = Path(args.plan)
    output_path = Path(args.output)

    # Parse the complete module plan before changing Spack flags or modulefiles.
    try:
        with plan_path.open(encoding="utf-8", newline="") as stream:
            rows = list(csv.DictReader(stream, delimiter="\t"))
    except FileNotFoundError as error:
        raise ManifestError(f"module plan does not exist: {plan_path}") from error
    fail_unless(
        rows and set(PLAN_FIELDS).issubset(rows[0]),
        "module plan is empty or invalid",
    )

    hashes = [clean_hash(row.get("hash"), "module plan hash") for row in rows]
    fail_unless(
        len(hashes) == len(set(hashes)), "module plan contains duplicate hashes"
    )
    refresh_writers, module_root, annotations = prepare_lmod_modules(
        rows, hashes, spack_modules, spack_store
    )

    if refresh_writers:
        print(f"Regenerating {len(refresh_writers)} environment Lmod modules...")
        spack_modules.common.generate_module_index(module_root, refresh_writers)
        for position, writer in enumerate(refresh_writers, 1):
            try:
                writer.write(overwrite=True)
            except Exception as error:
                raise ManifestError(
                    f"could not write Lmod module for /{writer.spec.dag_hash()}: "
                    f"{error}"
                ) from error
            if position % args.progress_every == 0 or position == len(refresh_writers):
                print(
                    f"Regenerated {position}/{len(refresh_writers)} "
                    "environment modules.",
                    flush=True,
                )

    changed = normalise_hide_versions(module_root)
    print(f"Normalised {changed} Lmod visibility files.")

    # Validate all generated modulefile paths before writing the annotations.
    print(f"Recording module metadata for {len(rows)} installed specs...")
    lines = []
    for position, annotation in enumerate(annotations, 1):
        node_hash, prefix, module_name, module_path = annotation
        fail_unless(
            module_path and Path(module_path).is_file(),
            f"invalid Lmod path for /{node_hash}: {module_path}",
        )
        lines.append(f"{node_hash}\t{prefix}\t{module_name}\t{module_path}\n")
        if position % args.progress_every == 0 or position == len(rows):
            print(
                f"Recorded module metadata for {position}/{len(rows)} specs.",
                flush=True,
            )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("".join(lines), encoding="utf-8")


def command_validate(args):
    """Validate the published manifest against expected deployment metadata."""
    manifest = read_json(Path(args.manifest), "installation manifest")
    validate_manifest(manifest, complete=True, check_paths=not args.skip_path_checks)
    fail_unless(
        manifest["system"] == args.system,
        f"manifest system is {manifest['system']!r}, expected {args.system!r}",
    )
    fail_unless(
        Path(manifest["install_prefix"])
        == absolute_path(args.install_prefix, "install prefix"),
        "manifest install prefix does not match",
    )
    missing = sorted(set(args.environment) - set(manifest["sources"]["environments"]))
    fail_unless(not missing, f"manifest is missing environments: {', '.join(missing)}")
    print(args.manifest)


def add_root_argument(parser):
    parser.add_argument("--metadata-root")


def add_source_arguments(parser, environment_only=False):
    if not environment_only:
        parser.add_argument(
            "--kind", choices=("standalone", "environment"), required=True
        )
    parser.add_argument("--name", required=True)


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    command = subparsers.add_parser("init")
    add_root_argument(command)
    command.add_argument("--system", required=True)
    command.add_argument("--date-tag", required=True)
    command.add_argument("--install-prefix", required=True)
    command.add_argument("--spack-version", required=True)
    command.add_argument("--run-id")
    command.set_defaults(function=command_init)

    command = subparsers.add_parser("reset-source")
    add_root_argument(command)
    add_source_arguments(command)
    command.set_defaults(function=command_reset_source)

    command = subparsers.add_parser("record-spec")
    add_root_argument(command)
    add_source_arguments(command)
    command.add_argument("--requested-spec", required=True)
    command.add_argument("--spec-file", required=True)
    command.add_argument(
        "--install-mode", choices=("root", "dependencies-only"), default="root"
    )
    command.set_defaults(function=command_record_spec)

    command = subparsers.add_parser("record-lockfile")
    add_root_argument(command)
    add_source_arguments(command, environment_only=True)
    command.add_argument("--lock-file", required=True)
    command.add_argument(
        "--install-mode", choices=("root", "dependencies-only"), default="root"
    )
    command.set_defaults(function=command_record_lockfile)

    command = subparsers.add_parser("seal-source")
    add_root_argument(command)
    add_source_arguments(command)
    command.set_defaults(function=command_seal_source)

    command = subparsers.add_parser("assemble")
    add_root_argument(command)
    command.add_argument("--standalone", action="append", default=[])
    command.add_argument("--environment", action="append", default=[])
    command.add_argument("--output")
    command.add_argument("--plan")
    command.set_defaults(function=command_assemble)

    command = subparsers.add_parser("publish")
    add_root_argument(command)
    command.add_argument("--candidate")
    command.add_argument("--annotations", required=True)
    command.add_argument("--output")
    command.set_defaults(function=command_publish)

    command = subparsers.add_parser("annotate-modules")
    command.add_argument("--plan", required=True)
    command.add_argument("--output", required=True)
    command.add_argument("--progress-every", type=int, default=25)
    command.set_defaults(function=command_annotate_modules)

    command = subparsers.add_parser("validate")
    command.add_argument("--manifest", required=True)
    command.add_argument("--system", default="setonix-q")
    command.add_argument("--install-prefix", required=True)
    command.add_argument("--environment", action="append", default=[])
    command.add_argument("--skip-path-checks", action="store_true")
    command.set_defaults(function=command_validate)
    return parser


def main(argv=None):
    try:
        args = build_parser().parse_args(argv)
        args.function(args)
        return 0
    except ManifestError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
