#!/usr/bin/env python3
"""Create and query durable receipts for a Pawsey Spack installation.

The installer intentionally concretizes some requested roots outside their source
environments.  Consequently, an environment lockfile is not necessarily a
record of the hashes that were installed.  This helper records the concrete
specification used for each successful install and assembles those receipts into
the authoritative module-generation and ReFrame manifest.

This module deliberately uses only the Python standard library.  It is invoked
while the stack's Python/Spack bootstrap is still in progress.
"""

from __future__ import annotations

import argparse
import copy
import datetime
import hashlib
import json
import os
import re
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, MutableMapping, Optional, Sequence, Set, Tuple


SCHEMA_VERSION = 1
RUN_FILE = "receipts/deployment.json"
CANDIDATE_FILE = "spack_install_manifest.candidate.json"
FINAL_FILE = "spack_install_manifest.json"
HASH_RE = re.compile(r"^[a-z0-9]{7,64}$")
SOURCE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.+-]*$")


class ManifestError(RuntimeError):
    """An input or manifest invariant was violated."""


def _utc_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def _normalise_absolute_path(value: str, label: str) -> str:
    if not value or "\x00" in value:
        raise ManifestError(f"{label} must be a non-empty path")
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    return os.path.normpath(str(path))


def _metadata_root(args: argparse.Namespace) -> Path:
    value = getattr(args, "metadata_root", None)
    if not value:
        install_prefix = os.environ.get("INSTALL_PREFIX")
        if not install_prefix:
            raise ManifestError("--metadata-root or INSTALL_PREFIX is required")
        value = str(Path(install_prefix) / "installation_metadata")
    return Path(_normalise_absolute_path(value, "metadata root"))


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def _atomic_write_bytes(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(str(temporary), 0o664)
        os.replace(str(temporary), str(path))
        try:
            directory_descriptor = os.open(str(path.parent), os.O_RDONLY)
            try:
                os.fsync(directory_descriptor)
            finally:
                os.close(directory_descriptor)
        except OSError:
            # Directory fsync is unavailable on a few filesystems.  The file
            # itself has still been fsynced and atomically renamed.
            pass
    finally:
        if temporary.exists():
            temporary.unlink()


def _atomic_write_json(path: Path, value: Any) -> None:
    _atomic_write_bytes(path, _json_bytes(value))


def _load_json(path: Path, label: str) -> Any:
    try:
        with path.open("r", encoding="utf-8") as stream:
            return json.load(stream)
    except FileNotFoundError as error:
        raise ManifestError(f"{label} does not exist: {path}") from error
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ManifestError(f"{label} is not valid UTF-8 JSON: {path}: {error}") from error


def _validate_hash(value: Any, label: str = "hash") -> str:
    if not isinstance(value, str) or not HASH_RE.fullmatch(value):
        raise ManifestError(f"invalid {label}: {value!r}")
    return value


def _validate_source_name(value: str) -> str:
    if not SOURCE_NAME_RE.fullmatch(value):
        raise ManifestError(
            f"invalid source name {value!r}; use letters, digits, '.', '_', '+', or '-'"
        )
    return value


def _validate_single_line(value: str, label: str) -> str:
    if not value or any(character in value for character in ("\t", "\r", "\n", "\x00")):
        raise ManifestError(f"{label} must be non-empty and must not contain tabs or newlines")
    return value


def _safe_relative_path(root: Path, path: Path, label: str) -> str:
    root_absolute = str(root.resolve(strict=False))
    path_absolute = str(path.resolve(strict=False))
    try:
        common = os.path.commonpath((root_absolute, path_absolute))
    except ValueError as error:
        raise ManifestError(f"{label} is outside the metadata root: {path}") from error
    if common != root_absolute:
        raise ManifestError(f"{label} is outside the metadata root: {path}")
    return Path(os.path.relpath(path_absolute, root_absolute)).as_posix()


def _run_path(root: Path) -> Path:
    return root / RUN_FILE


def _candidate_path(root: Path) -> Path:
    return root / CANDIDATE_FILE


def _final_path(root: Path) -> Path:
    return root / FINAL_FILE


def _archive_final_manifest(root: Path) -> Optional[Path]:
    """Move the published manifest out of the well-known path, if present.

    Receipt resets can happen within one deployment run (for example, when the
    separately scheduled ROCm environment is added).  Keep every distinct
    published view as useful history while ensuring consumers never observe a
    stale manifest during the replacement operation.
    """
    previous_final = _final_path(root)
    if not previous_final.exists():
        return None

    previous = _load_json(previous_final, "previous final installation manifest")
    previous_identity = previous.get("identity", {}) if isinstance(previous, dict) else {}
    previous_date_tag = str(previous_identity.get("date_tag", "unknown"))
    previous_run_id = str(previous.get("run_id", "unknown")) if isinstance(previous, dict) else "unknown"
    safe_date_tag = re.sub(r"[^A-Za-z0-9_.+-]", "_", previous_date_tag)
    safe_run_id = re.sub(r"[^A-Za-z0-9_.+-]", "_", previous_run_id)
    history_directory = root / "history" / safe_date_tag
    history_directory.mkdir(parents=True, exist_ok=True)
    archive = history_directory / f"{safe_run_id}-{FINAL_FILE}"

    if archive.exists() and archive.read_bytes() != previous_final.read_bytes():
        timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        archive = history_directory / (
            f"{safe_run_id}-{timestamp}-{uuid.uuid4().hex[:8]}-{FINAL_FILE}"
        )
    if archive.exists():
        # An identical retry does not need a second historical copy.
        previous_final.unlink()
    else:
        os.replace(str(previous_final), str(archive))
    return archive


def _load_run(root: Path) -> Dict[str, Any]:
    run = _load_json(_run_path(root), "installation run metadata")
    if not isinstance(run, dict) or run.get("schema_version") != SCHEMA_VERSION:
        raise ManifestError(f"unsupported installation run metadata in {_run_path(root)}")
    if run.get("artifact_type") != "pawsey-spack-installation-run":
        raise ManifestError(f"unexpected artifact type in {_run_path(root)}")
    run_id = run.get("run_id")
    identity = run.get("identity")
    if not isinstance(run_id, str) or not run_id:
        raise ManifestError("installation run metadata has no run_id")
    receipt_revision = run.get("receipt_revision")
    if not isinstance(receipt_revision, int) or isinstance(receipt_revision, bool) or receipt_revision < 0:
        raise ManifestError("installation run metadata has an invalid receipt_revision")
    if not isinstance(identity, dict) or any(
        not identity.get(field)
        for field in ("system", "date_tag", "install_prefix", "spack_version")
    ):
        raise ManifestError("installation run metadata has an invalid identity")
    return run


def _receipt_path(root: Path, source_type: str, source_name: str) -> Path:
    _validate_source_name(source_name)
    if source_type == "standalone":
        return root / "receipts" / "standalone" / f"{source_name}.json"
    if source_type == "environment":
        return root / "receipts" / "environments" / f"{source_name}.json"
    raise ManifestError(f"unsupported source type: {source_type}")


def _concrete_spec_path(root: Path, root_hash: str) -> Path:
    return root / "concrete_specs" / f"{_validate_hash(root_hash, 'root hash')}.json"


def _parse_spec_v4(data: Any, label: str) -> Tuple[str, List[Dict[str, Any]], Dict[str, Dict[str, Any]]]:
    if not isinstance(data, dict) or not isinstance(data.get("spec"), dict):
        raise ManifestError(f"{label} is not a Spack spec JSON object")
    spec = data["spec"]
    meta = spec.get("_meta")
    if not isinstance(meta, dict) or meta.get("version") != 4:
        raise ManifestError(f"{label} must use Spack spec JSON version 4")
    nodes = spec.get("nodes")
    if not isinstance(nodes, list) or not nodes:
        raise ManifestError(f"{label} has no concrete spec nodes")

    indexed: Dict[str, Dict[str, Any]] = {}
    for position, node in enumerate(nodes):
        if not isinstance(node, dict):
            raise ManifestError(f"{label} node {position} is not an object")
        node_hash = _validate_hash(node.get("hash"), f"node {position} hash")
        if node_hash in indexed:
            raise ManifestError(f"{label} contains duplicate node hash {node_hash}")
        if not isinstance(node.get("name"), str) or not node["name"]:
            raise ManifestError(f"{label} node {node_hash} has no name")
        dependencies = node.get("dependencies", [])
        if not isinstance(dependencies, list):
            raise ManifestError(f"{label} node {node_hash} dependencies are not a list")
        for dependency in dependencies:
            if not isinstance(dependency, dict):
                raise ManifestError(f"{label} node {node_hash} has an invalid dependency")
            _validate_hash(dependency.get("hash"), f"dependency hash of {node_hash}")
        build_spec = node.get("build_spec")
        if build_spec is not None:
            if not isinstance(build_spec, dict):
                raise ManifestError(f"{label} node {node_hash} has an invalid build_spec")
            _validate_hash(build_spec.get("hash"), f"build_spec hash of {node_hash}")
        indexed[node_hash] = node

    for node_hash, node in indexed.items():
        for dependency in node.get("dependencies", []):
            dependency_hash = dependency["hash"]
            if dependency_hash not in indexed:
                raise ManifestError(
                    f"{label} node {node_hash} refers to missing dependency {dependency_hash}"
                )
        build_spec = node.get("build_spec")
        if build_spec is not None and build_spec["hash"] not in indexed:
            raise ManifestError(
                f"{label} node {node_hash} refers to missing build_spec {build_spec['hash']}"
            )

    root_hash = nodes[0]["hash"]
    reachable: Set[str] = set()
    pending = [root_hash]
    while pending:
        current = pending.pop()
        if current in reachable:
            continue
        reachable.add(current)
        current_node = indexed[current]
        pending.extend(dependency["hash"] for dependency in current_node.get("dependencies", []))
        if current_node.get("build_spec") is not None:
            pending.append(current_node["build_spec"]["hash"])
    unreferenced = set(indexed) - reachable
    if unreferenced:
        raise ManifestError(
            f"{label} contains nodes unreachable from root {root_hash}: "
            + ", ".join(sorted(unreferenced))
        )
    return root_hash, nodes, indexed


def _load_spec_file(path: Path) -> Tuple[Any, str, List[Dict[str, Any]], Dict[str, Dict[str, Any]]]:
    data = _load_json(path, "concrete spec")
    root_hash, nodes, indexed = _parse_spec_v4(data, str(path))
    return data, root_hash, nodes, indexed


def _store_spec(root: Path, source: Path) -> Tuple[str, Path, str]:
    run = _load_run(root)
    del run  # Requiring an active run prevents orphaned receipt artifacts.
    try:
        payload = source.read_bytes()
    except FileNotFoundError as error:
        raise ManifestError(f"concrete spec does not exist: {source}") from error
    try:
        data = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ManifestError(f"concrete spec is not valid UTF-8 JSON: {source}: {error}") from error
    root_hash, _nodes, _indexed = _parse_spec_v4(data, str(source))
    destination = _concrete_spec_path(root, root_hash)
    if destination.exists():
        existing = _load_json(destination, "stored concrete spec")
        if existing != data:
            raise ManifestError(
                f"stored concrete spec {destination} conflicts with another spec for {root_hash}"
            )
    else:
        _atomic_write_bytes(destination, payload)
    return root_hash, destination, hashlib.sha256(destination.read_bytes()).hexdigest()


def _load_receipt(root: Path, source_type: str, source_name: str, run: Mapping[str, Any]) -> Dict[str, Any]:
    path = _receipt_path(root, source_type, source_name)
    receipt = _load_json(path, f"{source_type} receipt {source_name}")
    if not isinstance(receipt, dict) or receipt.get("schema_version") != SCHEMA_VERSION:
        raise ManifestError(f"unsupported receipt schema: {path}")
    if receipt.get("artifact_type") != "pawsey-spack-installation-receipt":
        raise ManifestError(f"unexpected receipt artifact type: {path}")
    if receipt.get("run_id") != run["run_id"]:
        raise ManifestError(
            f"stale receipt {path}: run_id {receipt.get('run_id')!r} does not match "
            f"active run {run['run_id']!r}"
        )
    if receipt.get("identity") != run["identity"]:
        raise ManifestError(f"receipt identity does not match the active run: {path}")
    if receipt.get("source") != {"type": source_type, "name": source_name}:
        raise ManifestError(f"receipt source does not match its path: {path}")
    receipt_revision = receipt.get("receipt_revision")
    if (
        not isinstance(receipt_revision, int)
        or isinstance(receipt_revision, bool)
        or receipt_revision < 1
        or receipt_revision > run["receipt_revision"]
    ):
        raise ManifestError(f"receipt has an invalid receipt_revision: {path}")
    if receipt.get("status") not in ("recording", "complete"):
        raise ManifestError(f"receipt has an invalid status: {path}")
    if receipt.get("status") == "complete" and not isinstance(receipt.get("sealed_at"), str):
        raise ManifestError(f"complete receipt has no sealed_at timestamp: {path}")
    if receipt.get("status") == "complete":
        sealed_receipt = receipt.get("sealed_receipt")
        if not isinstance(sealed_receipt, str):
            raise ManifestError(f"complete receipt has no immutable sealed_receipt path: {path}")
        _safe_relative_path(root, root / sealed_receipt, "sealed receipt")
    roots = receipt.get("roots")
    if not isinstance(roots, list):
        raise ManifestError(f"receipt has no roots list: {path}")
    return receipt


def _root_record_installed_hashes(indexed: Mapping[str, Any], root_hash: str, mode: str) -> List[str]:
    # Spack appends build-spec provenance DAGs to v4 spec files for spliced
    # specs.  They are needed to reconstruct the spec, but are not part of the
    # active dependency traversal used for module generation.
    hashes: Set[str] = set()
    pending = [root_hash]
    while pending:
        current = pending.pop()
        if current in hashes:
            continue
        hashes.add(current)
        pending.extend(
            dependency["hash"] for dependency in indexed[current].get("dependencies", [])
        )
    if mode == "dependencies-only":
        hashes.discard(root_hash)
    return sorted(hashes)


def command_init(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    install_prefix = _normalise_absolute_path(args.install_prefix, "install prefix")
    expected_root = os.path.normpath(str(Path(install_prefix) / "installation_metadata"))
    if os.path.normpath(str(root)) != expected_root:
        raise ManifestError(
            f"metadata root must be <install-prefix>/installation_metadata: expected {expected_root}, "
            f"got {root}"
        )
    system = _validate_single_line(args.system, "system")
    date_tag = _validate_single_line(args.date_tag, "date tag")
    spack_version = _validate_single_line(args.spack_version, "Spack version")
    run_id = args.run_id or f"{datetime.datetime.now(datetime.timezone.utc):%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:12]}"
    _validate_single_line(run_id, "run id")
    identity = {
        "system": system,
        "date_tag": date_tag,
        "install_prefix": install_prefix,
        "spack_version": spack_version,
    }
    run_path = _run_path(root)
    if run_path.exists() and args.run_id:
        existing = _load_run(root)
        if existing["run_id"] == run_id:
            if existing["identity"] != identity:
                raise ManifestError(f"run_id {run_id!r} already exists with a different identity")
            print(run_id)
            return

    for directory in (
        root / "concrete_specs",
        root / "receipts" / "standalone",
        root / "receipts" / "environments",
    ):
        directory.mkdir(parents=True, exist_ok=True)

    # Never leave a completed manifest from the previous deployment at the
    # well-known path while a new deployment is in progress.
    _archive_final_manifest(root)
    run = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "pawsey-spack-installation-run",
        "run_id": run_id,
        "created_at": _utc_now(),
        "receipt_revision": 0,
        "identity": identity,
    }
    _atomic_write_json(run_path, run)
    print(run_id)


def command_reset_receipt(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    run = _load_run(root)
    source_name = _validate_source_name(args.source_name)
    path = _receipt_path(root, args.source_type, source_name)
    # Resetting any source makes the aggregate publication stale.  Archive it
    # before exposing the empty replacement receipt.
    _archive_final_manifest(root)
    run["receipt_revision"] += 1
    run["updated_at"] = _utc_now()
    _atomic_write_json(_run_path(root), run)
    now = _utc_now()
    receipt = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "pawsey-spack-installation-receipt",
        "run_id": run["run_id"],
        "receipt_revision": run["receipt_revision"],
        "identity": copy.deepcopy(run["identity"]),
        "source": {"type": args.source_type, "name": source_name},
        "status": "recording",
        "created_at": now,
        "updated_at": now,
        "roots": [],
        "installed_hashes": [],
    }
    _atomic_write_json(path, receipt)
    print(path)


def command_store_spec(args: argparse.Namespace) -> None:
    root_hash, _destination, _sha256 = _store_spec(_metadata_root(args), Path(args.spec_file))
    print(root_hash)


def command_record(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    run = _load_run(root)
    source_name = _validate_source_name(args.source_name)
    requested_spec = _validate_single_line(args.requested_spec, "requested spec")
    receipt_path = _receipt_path(root, args.source_type, source_name)
    receipt = _load_receipt(root, args.source_type, source_name, run)
    if receipt.get("status") != "recording":
        raise ManifestError(
            f"receipt for {args.source_type} {source_name!r} is not open for recording"
        )
    root_hash, stored_path, source_sha256 = _store_spec(root, Path(args.spec_file))
    stored_data, stored_hash, _nodes, indexed = _load_spec_file(stored_path)
    del stored_data
    if root_hash != stored_hash:
        raise ManifestError(f"stored concrete spec root changed unexpectedly: {stored_path}")
    installed = args.install_mode == "root"
    installed_hashes = _root_record_installed_hashes(indexed, root_hash, args.install_mode)
    record = {
        "requested_spec": requested_spec,
        "hash": root_hash,
        "root_hash": root_hash,
        "install_mode": args.install_mode,
        "installed": installed,
        "installed_hashes": installed_hashes,
        "concrete_spec": _safe_relative_path(root, stored_path, "concrete spec"),
        "concrete_spec_sha256": source_sha256,
        "recorded_at": _utc_now(),
    }
    equivalence_fields = ("requested_spec", "root_hash", "install_mode")
    duplicate = next(
        (
            existing
            for existing in receipt["roots"]
            if all(existing.get(field) == record[field] for field in equivalence_fields)
        ),
        None,
    )
    if duplicate is None:
        receipt["roots"].append(record)
    else:
        # Idempotent retries retain the original recorded_at value.
        for field in ("installed", "installed_hashes", "concrete_spec", "concrete_spec_sha256"):
            if duplicate.get(field) != record[field]:
                raise ManifestError(
                    f"receipt already contains a conflicting record for {requested_spec!r}"
                )
    receipt["roots"].sort(
        key=lambda item: (item["requested_spec"], item["root_hash"], item["install_mode"])
    )
    receipt["installed_hashes"] = sorted(
        {item for entry in receipt["roots"] for item in entry["installed_hashes"]}
    )
    receipt["updated_at"] = _utc_now()
    _atomic_write_json(receipt_path, receipt)
    print(root_hash)


def command_seal_receipt(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    run = _load_run(root)
    source_name = _validate_source_name(args.source_name)
    receipt_path = _receipt_path(root, args.source_type, source_name)
    receipt = _load_receipt(root, args.source_type, source_name, run)
    if receipt.get("status") == "complete":
        # Idempotent sealing is useful when a successfully completed producer
        # is resumed after an unrelated later workflow step failed.
        print(receipt_path)
        return
    if receipt.get("status") != "recording":
        raise ManifestError(
            f"receipt for {args.source_type} {source_name!r} has invalid status "
            f"{receipt.get('status')!r}"
        )
    if not receipt["roots"]:
        raise ManifestError(
            f"cannot seal receipt for {args.source_type} {source_name!r} without roots"
        )
    expected_hashes = sorted(
        {node_hash for root_record in receipt["roots"] for node_hash in root_record["installed_hashes"]}
    )
    if receipt.get("installed_hashes") != expected_hashes:
        raise ManifestError(
            f"receipt for {args.source_type} {source_name!r} has inconsistent installed hashes"
        )
    now = _utc_now()
    receipt["status"] = "complete"
    receipt["sealed_at"] = now
    receipt["updated_at"] = now
    safe_run_id = re.sub(r"[^A-Za-z0-9_.+-]", "_", run["run_id"])
    snapshot_path = (
        root
        / "receipts"
        / "sealed"
        / safe_run_id
        / args.source_type
        / f"{receipt['receipt_revision']}-{source_name}.json"
    )
    receipt["sealed_receipt"] = _safe_relative_path(root, snapshot_path, "sealed receipt")
    if snapshot_path.exists():
        if _load_json(snapshot_path, "sealed receipt") != receipt:
            raise ManifestError(f"refusing to overwrite conflicting sealed receipt {snapshot_path}")
    else:
        _atomic_write_json(snapshot_path, receipt)
    _atomic_write_json(receipt_path, receipt)
    print(receipt_path)


def _load_lockfile(path: Path) -> Dict[str, Any]:
    lock = _load_json(path, "Spack lockfile")
    if not isinstance(lock, dict):
        raise ManifestError(f"Spack lockfile is not an object: {path}")
    meta = lock.get("_meta")
    if not isinstance(meta, dict) or meta.get("lockfile-version") != 5:
        raise ManifestError(f"Spack lockfile must use lockfile version 5: {path}")
    if meta.get("specfile-version") != 4:
        raise ManifestError(f"Spack lockfile must use specfile version 4: {path}")
    roots = lock.get("roots")
    concrete_specs = lock.get("concrete_specs")
    if not isinstance(roots, list) or not isinstance(concrete_specs, dict):
        raise ManifestError(f"Spack lockfile has invalid roots or concrete_specs: {path}")
    seen: Set[str] = set()
    for position, root in enumerate(roots):
        if not isinstance(root, dict):
            raise ManifestError(f"lockfile root {position} is not an object: {path}")
        root_hash = _validate_hash(root.get("hash"), f"lockfile root {position} hash")
        _validate_single_line(root.get("spec"), f"lockfile root {position} spec")
        if root_hash in seen:
            raise ManifestError(f"duplicate lockfile root hash {root_hash}: {path}")
        if root_hash not in concrete_specs:
            raise ManifestError(f"lockfile root {root_hash} has no concrete spec: {path}")
        seen.add(root_hash)
    for key, node in concrete_specs.items():
        node_hash = _validate_hash(key, "concrete_specs key")
        if not isinstance(node, dict) or node.get("hash") != node_hash:
            raise ManifestError(f"lockfile concrete spec key/hash mismatch for {key}: {path}")
        if not isinstance(node.get("name"), str) or not node["name"]:
            raise ManifestError(f"lockfile node {node_hash} has no name: {path}")
        dependencies = node.get("dependencies", [])
        if not isinstance(dependencies, list):
            raise ManifestError(f"lockfile node {node_hash} dependencies are invalid: {path}")
        for dependency in dependencies:
            if not isinstance(dependency, dict):
                raise ManifestError(f"lockfile node {node_hash} has an invalid dependency: {path}")
            dependency_hash = _validate_hash(
                dependency.get("hash"), f"dependency hash of lockfile node {node_hash}"
            )
            if dependency_hash not in concrete_specs:
                raise ManifestError(
                    f"lockfile node {node_hash} refers to missing dependency {dependency_hash}: {path}"
                )
        build_spec = node.get("build_spec")
        if build_spec is not None:
            if not isinstance(build_spec, dict):
                raise ManifestError(f"lockfile node {node_hash} has an invalid build_spec: {path}")
            build_hash = _validate_hash(
                build_spec.get("hash"), f"build_spec hash of lockfile node {node_hash}"
            )
            if build_hash not in concrete_specs:
                raise ManifestError(
                    f"lockfile node {node_hash} refers to missing build_spec {build_hash}: {path}"
                )
    return lock


def command_lock_roots(args: argparse.Namespace) -> None:
    lock = _load_lockfile(Path(args.lock_file))
    for root in lock["roots"]:
        print(f"{root['hash']}\t{root['spec']}")


def command_export_lock_spec(args: argparse.Namespace) -> None:
    lock = _load_lockfile(Path(args.lock_file))
    requested_hash = args.hash[1:] if args.hash.startswith("/") else args.hash
    root_hash = _validate_hash(requested_hash, "requested lockfile root hash")
    root_hashes = {entry["hash"] for entry in lock["roots"]}
    if root_hash not in root_hashes:
        raise ManifestError(f"hash {root_hash} is not a root in {args.lock_file}")
    indexed = lock["concrete_specs"]
    ordered: List[Dict[str, Any]] = []
    seen: Set[str] = set()

    def visit(node_hash: str) -> None:
        if node_hash in seen:
            return
        seen.add(node_hash)
        node = indexed[node_hash]
        ordered.append(copy.deepcopy(node))
        for dependency in node.get("dependencies", []):
            visit(dependency["hash"])
        if node.get("build_spec") is not None:
            visit(node["build_spec"]["hash"])

    visit(root_hash)
    exported = {"spec": {"_meta": {"version": 4}, "nodes": ordered}}
    # Re-validate the generated document before making it visible.
    parsed_root, _nodes, _indexed = _parse_spec_v4(exported, f"exported root {root_hash}")
    if parsed_root != root_hash:
        raise ManifestError(f"exported concrete spec has unexpected root {parsed_root}")
    output = Path(args.output)
    _atomic_write_json(output, exported)
    print(output)


def _canonical_node(node: Mapping[str, Any]) -> str:
    return json.dumps(node, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _source_summary(receipt: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "receipt": receipt["sealed_receipt"],
        "receipt_revision": receipt["receipt_revision"],
        "receipt_status": receipt["status"],
        "sealed_at": receipt["sealed_at"],
        "roots": copy.deepcopy(receipt["roots"]),
        "installed_hashes": copy.deepcopy(receipt["installed_hashes"]),
    }


def _reference_record(
    source_type: str, source_name: str, root_record: Mapping[str, Any]
) -> Dict[str, Any]:
    return {
        "source_type": source_type,
        "source_name": source_name,
        "requested_spec": root_record["requested_spec"],
        "hash": root_record["root_hash"],
        "root_hash": root_record["root_hash"],
        "install_mode": root_record["install_mode"],
        "installed": root_record["installed"],
    }


def _sort_references(references: Iterable[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    unique: Dict[str, Dict[str, Any]] = {}
    for reference in references:
        copied = copy.deepcopy(dict(reference))
        unique[json.dumps(copied, sort_keys=True, separators=(",", ":"))] = copied
    return sorted(
        unique.values(),
        key=lambda item: (
            item["source_type"],
            item["source_name"],
            item["requested_spec"],
            item["root_hash"],
        ),
    )


def command_assemble(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    run = _load_run(root)
    standalone_names = sorted(set(args.standalone))
    environment_names = sorted(set(args.environment))
    if not standalone_names and not environment_names:
        raise ManifestError("assemble requires at least one --standalone or --environment receipt")

    standalone: Dict[str, Any] = {}
    environments: Dict[str, Any] = {}
    receipts: List[Tuple[str, str, Dict[str, Any]]] = []
    for source_type, names, destination in (
        ("standalone", standalone_names, standalone),
        ("environment", environment_names, environments),
    ):
        for source_name in names:
            source_name = _validate_source_name(source_name)
            receipt = _load_receipt(root, source_type, source_name, run)
            if receipt.get("status") != "complete" or not receipt["roots"]:
                raise ManifestError(
                    f"receipt for {source_type} {source_name!r} is not a complete installation"
                )
            destination[source_name] = _source_summary(receipt)
            receipts.append((source_type, source_name, receipt))

    raw_nodes: Dict[str, Dict[str, Any]] = {}
    spec_files: Dict[str, Set[str]] = {}
    root_for: Dict[str, List[Dict[str, Any]]] = {}
    dependency_for: Dict[str, List[Dict[str, Any]]] = {}
    active_hashes: Set[str] = set()
    public_roots: Set[str] = set()

    for source_type, source_name, receipt in receipts:
        for root_record in receipt["roots"]:
            concrete_relative = root_record.get("concrete_spec")
            if not isinstance(concrete_relative, str):
                raise ManifestError(
                    f"receipt for {source_type} {source_name!r} has a root without a concrete spec"
                )
            concrete_path = root / concrete_relative
            _safe_relative_path(root, concrete_path, "receipt concrete spec")
            expected_sha256 = root_record.get("concrete_spec_sha256")
            if not isinstance(expected_sha256, str) or not re.fullmatch(
                r"[0-9a-f]{64}", expected_sha256
            ):
                raise ManifestError(
                    f"receipt root {root_record.get('root_hash')} has an invalid concrete spec digest"
                )
            try:
                actual_sha256 = hashlib.sha256(concrete_path.read_bytes()).hexdigest()
            except FileNotFoundError as error:
                raise ManifestError(f"receipt concrete spec does not exist: {concrete_path}") from error
            if actual_sha256 != expected_sha256:
                raise ManifestError(
                    f"receipt concrete spec digest does not match {concrete_path}"
                )
            _data, concrete_root, _nodes, indexed = _load_spec_file(concrete_path)
            if concrete_root != root_record.get("root_hash"):
                raise ManifestError(
                    f"receipt root {root_record.get('root_hash')} does not match {concrete_path}"
                )
            expected_installed = root_record.get("install_mode") == "root"
            if root_record.get("installed") is not expected_installed:
                raise ManifestError(
                    f"receipt root {concrete_root} has inconsistent install mode/installed marker"
                )
            expected_hashes = _root_record_installed_hashes(
                indexed, concrete_root, root_record["install_mode"]
            )
            if root_record.get("installed_hashes") != expected_hashes:
                raise ManifestError(f"receipt root {concrete_root} has inconsistent installed hashes")

            reference = _reference_record(source_type, source_name, root_record)
            root_for.setdefault(concrete_root, []).append(reference)
            if root_record["installed"]:
                public_roots.add(concrete_root)
            active_hashes.update(expected_hashes)
            for node_hash, node in indexed.items():
                previous = raw_nodes.get(node_hash)
                if previous is not None and _canonical_node(previous) != _canonical_node(node):
                    raise ManifestError(
                        f"concrete spec identity conflict for shared hash {node_hash}"
                    )
                raw_nodes[node_hash] = copy.deepcopy(node)
                spec_files.setdefault(node_hash, set()).add(concrete_relative)
                if node_hash != concrete_root and node_hash in expected_hashes:
                    dependency_for.setdefault(node_hash, []).append(reference)

    dependency_hashes = active_hashes - public_roots
    specs: Dict[str, Any] = {}
    for node_hash in sorted(raw_nodes):
        node = raw_nodes[node_hash]
        identity = copy.deepcopy(node)
        dependencies = identity.pop("dependencies", [])
        installed = node_hash in active_hashes
        module_role: Optional[str]
        if node_hash in public_roots:
            module_role = "public-root"
        elif installed:
            module_role = "dependency"
        else:
            module_role = None
        specs[node_hash] = {
            "hash": node_hash,
            "name": node["name"],
            "version": node.get("version"),
            "identity": identity,
            "dependencies": copy.deepcopy(dependencies),
            "installed": installed,
            "prefix": None,
            "root_for": _sort_references(root_for.get(node_hash, [])),
            "dependency_for": _sort_references(dependency_for.get(node_hash, [])),
            "concrete_spec_files": sorted(spec_files[node_hash]),
            "module": {"role": module_role, "use_name": None, "path": None},
        }

    now = _utc_now()
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "pawsey-spack-installation-manifest",
        "status": "candidate",
        "run_id": run["run_id"],
        "receipt_revision": run["receipt_revision"],
        "created_at": run["created_at"],
        "assembled_at": now,
        "system": run["identity"]["system"],
        "date_tag": run["identity"]["date_tag"],
        "install_prefix": run["identity"]["install_prefix"],
        "spack_version": run["identity"]["spack_version"],
        "identity": copy.deepcopy(run["identity"]),
        "standalone": standalone,
        "environments": environments,
        "active_hashes": sorted(active_hashes),
        "installed_hashes": sorted(active_hashes),
        "public_root_hashes": sorted(public_roots),
        "dependency_hashes": sorted(dependency_hashes),
        "specs": specs,
    }
    _validate_manifest_core(manifest, require_complete=False, check_paths=False)
    output = Path(args.output) if args.output else _candidate_path(root)
    if os.path.abspath(str(output)) == os.path.abspath(str(_final_path(root))):
        raise ManifestError("assemble output cannot overwrite the published manifest path")
    _atomic_write_json(output, manifest)
    print(output)


def _load_manifest(path: Path) -> Dict[str, Any]:
    manifest = _load_json(path, "installation manifest")
    if not isinstance(manifest, dict):
        raise ManifestError(f"installation manifest is not an object: {path}")
    return manifest


def _manifest_path_or_default(root: Path, value: Optional[str]) -> Path:
    return Path(value) if value else _candidate_path(root)


def _source_hashes(manifest: Mapping[str, Any], category: str) -> Set[str]:
    result: Set[str] = set()
    sources = manifest.get(category)
    if not isinstance(sources, dict):
        raise ManifestError(f"manifest has no valid {category} records")
    for source in sources.values():
        if not isinstance(source, dict) or not isinstance(source.get("installed_hashes"), list):
            raise ManifestError(f"manifest has an invalid {category} record")
        result.update(source["installed_hashes"])
    return result


def _source_roots(manifest: Mapping[str, Any], category: str) -> Set[str]:
    result: Set[str] = set()
    sources = manifest.get(category)
    if not isinstance(sources, dict):
        raise ManifestError(f"manifest has no valid {category} records")
    for source in sources.values():
        if not isinstance(source, dict) or not isinstance(source.get("roots"), list):
            raise ManifestError(f"manifest has an invalid {category} record")
        for root_record in source["roots"]:
            if root_record.get("installed") is True:
                result.add(root_record.get("root_hash", root_record.get("hash")))
    return result


def command_hashes(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    manifest = _load_manifest(_manifest_path_or_default(root, args.manifest))
    _validate_manifest_core(manifest, require_complete=False, check_paths=False)
    role = args.role
    all_hashes = set(manifest["installed_hashes"])
    public = set(manifest["public_root_hashes"])
    dependencies = set(manifest["dependency_hashes"])
    standalone_all = _source_hashes(manifest, "standalone")
    standalone_root = _source_roots(manifest, "standalone")
    environment_all = _source_hashes(manifest, "environments")
    environment_root = _source_roots(manifest, "environments")
    choices = {
        "all": all_hashes,
        "public-root": public,
        "dependency": dependencies,
        "standalone-all": standalone_all,
        "standalone-root": standalone_root,
        "environment-all": environment_all,
        "environment-root": environment_root,
        # Root publication role is global: a hash requested as a standalone root is
        # not an environment dependency for module-generation purposes.
        "environment-dependency": environment_all - public,
    }
    for node_hash in sorted(choices[role]):
        print(node_hash if args.bare else f"/{node_hash}")


def _manifest_source(
    manifest: Mapping[str, Any], source_type: str, source_name: str
) -> Mapping[str, Any]:
    category = "standalone" if source_type == "standalone" else "environments"
    sources = manifest.get(category)
    if not isinstance(sources, dict):
        raise ManifestError(f"manifest has invalid {category} records")
    source_name = _validate_source_name(source_name)
    source = sources.get(source_name)
    if not isinstance(source, dict):
        raise ManifestError(
            f"manifest has no {source_type} source named {source_name!r}"
        )
    return source


def command_source_roots(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    manifest = _load_manifest(Path(args.manifest))
    _validate_manifest_core(manifest, require_complete=True, check_paths=True)
    source = _manifest_source(manifest, args.source_type, args.source_name)
    for root_record in source["roots"]:
        root_hash = root_record.get("root_hash", root_record.get("hash"))
        spec = manifest["specs"].get(root_hash)
        if not isinstance(spec, dict):
            raise ManifestError(f"source root {root_hash!r} has no manifest spec record")
        values = (
            _validate_hash(root_hash, "source root hash"),
            _validate_single_line(str(spec.get("name", "")), "source root name"),
            _validate_single_line(str(spec.get("version", "")), "source root version"),
            "true" if root_record.get("installed") is True else "false",
            _validate_single_line(
                str(root_record.get("install_mode", "")), "source root install mode"
            ),
            _validate_single_line(
                str(root_record.get("requested_spec", "")), "source root requested spec"
            ),
        )
        print("\t".join(values))


def command_source_modules(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    manifest = _load_manifest(Path(args.manifest))
    _validate_manifest_core(manifest, require_complete=True, check_paths=True)
    source = _manifest_source(manifest, args.source_type, args.source_name)
    for node_hash in source["installed_hashes"]:
        spec = manifest["specs"].get(node_hash)
        if not isinstance(spec, dict) or spec.get("installed") is not True:
            raise ManifestError(f"source installed hash {node_hash} is not an installed spec")
        module = spec.get("module")
        if not isinstance(module, dict):
            raise ManifestError(f"source installed hash {node_hash} has no module metadata")
        use_name = _validate_single_line(
            str(module.get("use_name", "")), f"module use name for {node_hash}"
        )
        module_path = _normalise_absolute_path(
            str(module.get("path", "")), f"module path for {node_hash}"
        )
        print(f"{node_hash}\t{use_name}\t{module_path}")


def _iter_annotation_rows(stream: Iterable[str]) -> Iterable[Tuple[int, str, str, str, str]]:
    for line_number, raw_line in enumerate(stream, 1):
        line = raw_line.rstrip("\r\n")
        if not line or line.startswith("#"):
            continue
        columns = line.split("\t")
        if columns == ["hash", "prefix", "module-use-name", "module-path"]:
            continue
        if len(columns) != 4:
            raise ManifestError(
                f"annotation line {line_number} must have four tab-separated columns: "
                "hash, prefix, module-use-name, module-path"
            )
        yield line_number, columns[0], columns[1], columns[2], columns[3]


def command_annotate(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    manifest_path = _manifest_path_or_default(root, args.manifest)
    manifest = _load_manifest(manifest_path)
    _validate_manifest_core(manifest, require_complete=False, check_paths=False)
    if manifest.get("status") != "candidate":
        raise ManifestError("only a candidate manifest can be annotated")
    run = _load_run(root)
    if manifest.get("run_id") != run["run_id"]:
        raise ManifestError("candidate manifest belongs to a stale installation run")
    _validate_candidate_receipts(root, manifest, run)

    if args.input == "-":
        stream = sys.stdin
        close_stream = False
    else:
        try:
            stream = Path(args.input).open("r", encoding="utf-8")
        except FileNotFoundError as error:
            raise ManifestError(f"annotation TSV does not exist: {args.input}") from error
        close_stream = True
    annotations: Dict[str, Tuple[str, str, str]] = {}
    try:
        for line_number, hash_value, prefix, use_name, module_path in _iter_annotation_rows(stream):
            if hash_value.startswith("/"):
                hash_value = hash_value[1:]
            node_hash = _validate_hash(hash_value, f"annotation line {line_number} hash")
            if node_hash not in manifest["specs"] or not manifest["specs"][node_hash]["installed"]:
                raise ManifestError(
                    f"annotation line {line_number} refers to inactive or unknown hash {node_hash}"
                )
            prefix = _normalise_absolute_path(prefix, f"annotation line {line_number} prefix")
            use_name = _validate_single_line(
                use_name, f"annotation line {line_number} module use name"
            )
            module_path = _normalise_absolute_path(
                module_path, f"annotation line {line_number} module path"
            )
            value = (prefix, use_name, module_path)
            if node_hash in annotations and annotations[node_hash] != value:
                raise ManifestError(f"conflicting annotations for hash {node_hash}")
            annotations[node_hash] = value
    finally:
        if close_stream:
            stream.close()
    if not annotations:
        raise ManifestError("annotation TSV contained no records")
    for node_hash, (prefix, use_name, module_path) in annotations.items():
        entry = manifest["specs"][node_hash]
        entry["prefix"] = prefix
        entry["module"]["use_name"] = use_name
        entry["module"]["path"] = module_path
    manifest["annotated_at"] = _utc_now()
    manifest["annotated_hashes"] = sorted(
        node_hash
        for node_hash, entry in manifest["specs"].items()
        if entry["installed"]
        and entry.get("prefix")
        and entry.get("module", {}).get("use_name")
        and entry.get("module", {}).get("path")
    )
    _atomic_write_json(manifest_path, manifest)
    print(manifest_path)


def _ensure_string_list(value: Any, label: str) -> List[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise ManifestError(f"manifest {label} must be a list of strings")
    if value != sorted(set(value)):
        raise ManifestError(f"manifest {label} must be sorted and contain no duplicates")
    return value


def _validate_manifest_core(
    manifest: Mapping[str, Any], *, require_complete: bool, check_paths: bool
) -> None:
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise ManifestError("unsupported installation manifest schema")
    if manifest.get("artifact_type") != "pawsey-spack-installation-manifest":
        raise ManifestError("unexpected installation manifest artifact type")
    status = manifest.get("status")
    if require_complete:
        if status != "complete":
            raise ManifestError(f"final manifest status must be 'complete', got {status!r}")
    elif status not in ("candidate", "complete"):
        raise ManifestError(f"manifest has invalid status {status!r}")
    identity = manifest.get("identity")
    if not isinstance(identity, dict):
        raise ManifestError("manifest has no identity")
    if manifest.get("system") != identity.get("system"):
        raise ManifestError("manifest top-level system does not match identity.system")
    if manifest.get("date_tag") != identity.get("date_tag"):
        raise ManifestError("manifest top-level date_tag does not match identity.date_tag")
    if manifest.get("install_prefix") != identity.get("install_prefix"):
        raise ManifestError(
            "manifest top-level install_prefix does not match identity.install_prefix"
        )
    if manifest.get("spack_version") != identity.get("spack_version"):
        raise ManifestError(
            "manifest top-level spack_version does not match identity.spack_version"
        )
    if not isinstance(manifest.get("run_id"), str) or not manifest["run_id"]:
        raise ManifestError("manifest has no run_id")
    receipt_revision = manifest.get("receipt_revision")
    if not isinstance(receipt_revision, int) or isinstance(receipt_revision, bool) or receipt_revision < 0:
        raise ManifestError("manifest has an invalid receipt_revision")
    if not isinstance(manifest.get("standalone"), dict) or not isinstance(
        manifest.get("environments"), dict
    ):
        raise ManifestError("manifest source records are invalid")

    installed = set(_ensure_string_list(manifest.get("installed_hashes"), "installed_hashes"))
    active = set(_ensure_string_list(manifest.get("active_hashes"), "active_hashes"))
    public = set(
        _ensure_string_list(manifest.get("public_root_hashes"), "public_root_hashes")
    )
    dependencies = set(
        _ensure_string_list(manifest.get("dependency_hashes"), "dependency_hashes")
    )
    for node_hash in installed | active | public | dependencies:
        _validate_hash(node_hash)
    if active != installed:
        raise ManifestError("manifest active_hashes and installed_hashes differ")
    if public & dependencies or public | dependencies != installed:
        raise ManifestError(
            "manifest public roots and dependencies must be a disjoint partition of installed hashes"
        )

    source_installed = _source_hashes(manifest, "standalone") | _source_hashes(
        manifest, "environments"
    )
    source_roots = _source_roots(manifest, "standalone") | _source_roots(
        manifest, "environments"
    )
    if source_installed != installed:
        raise ManifestError("manifest source installed hashes do not match installed_hashes")
    if source_roots != public:
        raise ManifestError("manifest installed source roots do not match public_root_hashes")

    specs = manifest.get("specs")
    if not isinstance(specs, dict):
        raise ManifestError("manifest has no specs mapping")
    if not installed.issubset(specs):
        raise ManifestError("manifest specs mapping omits installed hashes")
    installed_from_specs: Set[str] = set()
    module_paths: Dict[str, str] = {}
    for node_hash, entry in specs.items():
        _validate_hash(node_hash, "spec key")
        if not isinstance(entry, dict) or entry.get("hash") != node_hash:
            raise ManifestError(f"manifest spec key/hash mismatch for {node_hash}")
        if not isinstance(entry.get("identity"), dict) or not isinstance(
            entry.get("dependencies"), list
        ):
            raise ManifestError(f"manifest spec {node_hash} has invalid identity/dependencies")
        for dependency in entry["dependencies"]:
            if not isinstance(dependency, dict):
                raise ManifestError(f"manifest spec {node_hash} has an invalid dependency")
            dependency_hash = _validate_hash(
                dependency.get("hash"), f"dependency hash of {node_hash}"
            )
            if dependency_hash not in specs:
                raise ManifestError(
                    f"manifest spec {node_hash} refers to absent spec {dependency_hash}"
                )
        is_installed = entry.get("installed")
        if not isinstance(is_installed, bool):
            raise ManifestError(f"manifest spec {node_hash} has no installed boolean")
        module = entry.get("module")
        if not isinstance(module, dict):
            raise ManifestError(f"manifest spec {node_hash} has invalid module metadata")
        expected_module_role = (
            "public-root"
            if node_hash in public
            else "dependency"
            if node_hash in dependencies
            else None
        )
        if module.get("role") != expected_module_role:
            raise ManifestError(f"manifest spec {node_hash} has inconsistent module role")
        if is_installed:
            installed_from_specs.add(node_hash)
        if check_paths and is_installed:
            prefix = entry.get("prefix")
            use_name = module.get("use_name")
            module_path = module.get("path")
            if not isinstance(prefix, str) or not os.path.isabs(prefix) or not Path(prefix).is_dir():
                raise ManifestError(f"installed spec {node_hash} has no existing prefix directory")
            if not isinstance(use_name, str) or not use_name:
                raise ManifestError(f"installed spec {node_hash} has no module use name")
            if (
                not isinstance(module_path, str)
                or not os.path.isabs(module_path)
                or not Path(module_path).is_file()
            ):
                raise ManifestError(f"installed spec {node_hash} has no existing module file")
            previous_path_hash = module_paths.get(module_path)
            if previous_path_hash and previous_path_hash != node_hash:
                raise ManifestError(
                    f"module path collision between {previous_path_hash} and {node_hash}: {module_path}"
                )
            module_paths[module_path] = node_hash
    if installed_from_specs != installed:
        raise ManifestError("manifest spec installed markers do not match installed_hashes")


def _validate_candidate_receipts(
    root: Path, candidate: Mapping[str, Any], run: Mapping[str, Any]
) -> None:
    if candidate.get("receipt_revision") != run["receipt_revision"]:
        raise ManifestError(
            "candidate manifest is stale because installation receipts were reset after assembly"
        )
    for source_type, category in (
        ("standalone", "standalone"),
        ("environment", "environments"),
    ):
        sources = candidate.get(category)
        if not isinstance(sources, dict):
            raise ManifestError(f"candidate manifest has invalid {category} records")
        for source_name, recorded_summary in sources.items():
            source_name = _validate_source_name(source_name)
            receipt = _load_receipt(root, source_type, source_name, run)
            current_summary = _source_summary(receipt)
            if current_summary != recorded_summary:
                raise ManifestError(
                    f"candidate manifest is stale because the {source_type} "
                    f"receipt {source_name!r} changed after assembly"
                )


def command_publish(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    candidate_path = _manifest_path_or_default(root, args.candidate)
    candidate = _load_manifest(candidate_path)
    _validate_manifest_core(candidate, require_complete=False, check_paths=False)
    if candidate.get("status") != "candidate":
        raise ManifestError("publish requires a candidate manifest")
    run = _load_run(root)
    if candidate.get("run_id") != run["run_id"] or candidate.get("identity") != run["identity"]:
        raise ManifestError("candidate manifest belongs to a stale or different installation run")
    _validate_candidate_receipts(root, candidate, run)
    _validate_manifest_core(candidate, require_complete=False, check_paths=True)
    final = copy.deepcopy(candidate)
    final["status"] = "complete"
    final["published_at"] = _utc_now()
    _validate_manifest_core(final, require_complete=True, check_paths=True)
    output = Path(args.output) if args.output else _final_path(root)
    if os.path.abspath(str(output)) == os.path.abspath(str(candidate_path)):
        raise ManifestError("candidate and final manifest paths must differ")
    _atomic_write_json(output, final)
    print(output)


def command_validate(args: argparse.Namespace) -> None:
    root = _metadata_root(args)
    phase = args.phase or ("final" if args.require_complete else "preflight")
    if args.require_complete and phase != "final":
        raise ManifestError("--require-complete cannot be combined with --phase preflight")
    default = _final_path(root) if phase == "final" else _candidate_path(root)
    path = Path(args.manifest) if args.manifest else default
    manifest = _load_manifest(path)
    _validate_manifest_core(
        manifest, require_complete=phase == "final", check_paths=phase == "final"
    )
    expected_system = _validate_single_line(args.expected_system, "expected system")
    expected_prefix = _normalise_absolute_path(args.expected_prefix, "expected install prefix")
    if manifest["system"] != expected_system:
        raise ManifestError(
            f"manifest system {manifest['system']!r} does not match expected {expected_system!r}"
        )
    if manifest["install_prefix"] != expected_prefix:
        raise ManifestError(
            f"manifest install prefix {manifest['install_prefix']!r} does not match expected "
            f"{expected_prefix!r}"
        )
    expected_environments = sorted(set(args.environment))
    actual_environments = sorted(manifest["environments"])
    missing_environments = sorted(set(expected_environments) - set(actual_environments))
    if missing_environments:
        raise ManifestError(
            "manifest is missing expected environments: "
            f"missing={missing_environments!r}, actual={actual_environments!r}"
        )
    if args.standalone:
        expected_standalone = sorted(set(args.standalone))
        actual_standalone = sorted(manifest["standalone"])
        if actual_standalone != expected_standalone:
            raise ManifestError(
                "manifest standalone sources do not match expected sources: "
                f"actual={actual_standalone!r}, expected={expected_standalone!r}"
            )
    print(path)


def _add_spec_file_argument(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--spec-file",
        "--input",
        dest="spec_file",
        required=True,
        help="Spack version-4 concrete spec JSON",
    )


def _add_metadata_root_argument(parser: argparse.ArgumentParser) -> None:
    # Suppressing the subparser default lets callers place this global option
    # either before or after the command name without one parser overwriting
    # the value set by the other.
    parser.add_argument(
        "--metadata-root",
        default=argparse.SUPPRESS,
        help="installation metadata root (default: $INSTALL_PREFIX/installation_metadata)",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--metadata-root",
        help="installation metadata root (default: $INSTALL_PREFIX/installation_metadata)",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="start a deployment metadata run")
    _add_metadata_root_argument(init_parser)
    init_parser.add_argument("--system", required=True)
    init_parser.add_argument("--date-tag", required=True)
    init_parser.add_argument("--install-prefix", required=True)
    init_parser.add_argument("--spack-version", required=True)
    init_parser.add_argument("--run-id", help="caller-supplied id for reproducible/idempotent setup")
    init_parser.set_defaults(function=command_init)

    reset_parser = subparsers.add_parser("reset-receipt", help="reset one source receipt")
    _add_metadata_root_argument(reset_parser)
    reset_parser.add_argument("--source-type", choices=("standalone", "environment"), required=True)
    reset_parser.add_argument("--source-name", required=True)
    reset_parser.set_defaults(function=command_reset_receipt)

    store_parser = subparsers.add_parser("store-spec", help="store a concrete spec by root hash")
    _add_metadata_root_argument(store_parser)
    _add_spec_file_argument(store_parser)
    store_parser.set_defaults(function=command_store_spec)

    record_parser = subparsers.add_parser("record", help="record a successful install")
    _add_metadata_root_argument(record_parser)
    record_parser.add_argument("--source-type", choices=("standalone", "environment"), required=True)
    record_parser.add_argument("--source-name", required=True)
    record_parser.add_argument("--requested-spec", required=True)
    _add_spec_file_argument(record_parser)
    record_parser.add_argument(
        "--install-mode", choices=("root", "dependencies-only"), default="root"
    )
    record_parser.set_defaults(function=command_record)

    seal_parser = subparsers.add_parser(
        "seal-receipt", help="mark one successfully completed source receipt publishable"
    )
    _add_metadata_root_argument(seal_parser)
    seal_parser.add_argument(
        "--source-type", choices=("standalone", "environment"), required=True
    )
    seal_parser.add_argument("--source-name", required=True)
    seal_parser.set_defaults(function=command_seal_receipt)

    lock_roots_parser = subparsers.add_parser(
        "lock-roots", help="emit lockfile roots as hash<TAB>requested-spec"
    )
    lock_roots_parser.add_argument("--lock-file", required=True)
    lock_roots_parser.set_defaults(function=command_lock_roots)

    export_parser = subparsers.add_parser(
        "export-lock-spec", help="export one lockfile root as Spack version-4 spec JSON"
    )
    export_parser.add_argument("--lock-file", required=True)
    export_parser.add_argument("--hash", required=True)
    export_parser.add_argument("--output", required=True)
    export_parser.set_defaults(function=command_export_lock_spec)

    assemble_parser = subparsers.add_parser("assemble", help="assemble active source receipts")
    _add_metadata_root_argument(assemble_parser)
    assemble_parser.add_argument("--standalone", action="append", default=[])
    assemble_parser.add_argument("--environment", action="append", default=[])
    assemble_parser.add_argument("--output")
    assemble_parser.set_defaults(function=command_assemble)

    hashes_parser = subparsers.add_parser("hashes", help="emit one selected hash per line")
    _add_metadata_root_argument(hashes_parser)
    hashes_parser.add_argument("--manifest")
    hashes_parser.add_argument(
        "--role",
        required=True,
        choices=(
            "all",
            "public-root",
            "dependency",
            "standalone-all",
            "standalone-root",
            "environment-all",
            "environment-root",
            "environment-dependency",
        ),
    )
    hashes_parser.add_argument("--bare", action="store_true", help="omit the leading '/'")
    hashes_parser.set_defaults(function=command_hashes)

    source_roots_parser = subparsers.add_parser(
        "source-roots",
        help="emit source roots as hash/name/version/installed/mode/requested-spec TSV",
    )
    _add_metadata_root_argument(source_roots_parser)
    source_roots_parser.add_argument("--manifest", required=True)
    source_roots_parser.add_argument(
        "--source-type", choices=("standalone", "environment"), required=True
    )
    source_roots_parser.add_argument("--source-name", required=True)
    source_roots_parser.set_defaults(function=command_source_roots)

    source_modules_parser = subparsers.add_parser(
        "source-modules",
        help="emit installed source modules as hash/use-name/path TSV",
    )
    _add_metadata_root_argument(source_modules_parser)
    source_modules_parser.add_argument("--manifest", required=True)
    source_modules_parser.add_argument(
        "--source-type", choices=("standalone", "environment"), required=True
    )
    source_modules_parser.add_argument("--source-name", required=True)
    source_modules_parser.set_defaults(function=command_source_modules)

    annotate_parser = subparsers.add_parser(
        "annotate", help="add prefix/module data from a four-column TSV"
    )
    _add_metadata_root_argument(annotate_parser)
    annotate_parser.add_argument("--manifest")
    annotate_parser.add_argument(
        "--input", "--annotations", dest="input", default="-", help="annotation TSV (default: stdin)"
    )
    annotate_parser.set_defaults(function=command_annotate)

    publish_parser = subparsers.add_parser(
        "publish", help="validate paths and atomically publish the final manifest"
    )
    _add_metadata_root_argument(publish_parser)
    publish_parser.add_argument("--candidate", "--manifest", dest="candidate")
    publish_parser.add_argument("--output")
    publish_parser.add_argument(
        "--check-paths",
        action="store_true",
        help="accepted for clarity; publish always validates prefixes and module paths",
    )
    publish_parser.set_defaults(function=command_publish)

    validate_parser = subparsers.add_parser("validate", help="validate a candidate or final manifest")
    _add_metadata_root_argument(validate_parser)
    validate_parser.add_argument("--manifest")
    validate_parser.add_argument("--phase", choices=("preflight", "final"))
    validate_parser.add_argument("--require-complete", action="store_true")
    validate_parser.add_argument("--expected-system", "--system", dest="expected_system", required=True)
    validate_parser.add_argument(
        "--expected-prefix",
        "--expected-install-prefix",
        "--install-prefix",
        dest="expected_prefix",
        required=True,
    )
    validate_parser.add_argument("--environment", action="append", default=[])
    validate_parser.add_argument("--standalone", action="append", default=[])
    validate_parser.set_defaults(function=command_validate)

    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.function(args)
    except ManifestError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except BrokenPipeError:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
