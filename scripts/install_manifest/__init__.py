"""Shared deployment inventory and public-module ReFrame helpers."""

import hashlib
import json
import os
import shlex
import tempfile
from functools import lru_cache
from pathlib import Path

SCHEMA_VERSION = 3
MANIFEST_FILE = "spack_install_manifest.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def file_stamp(path):
    stat = Path(path).stat()
    return stat.st_mtime_ns, stat.st_ctime_ns, stat.st_size, stat.st_ino


def source_digest(path):
    """Fingerprint Spack's inputs without interpreting their formats."""
    path = Path(path)
    stamps = tuple(file_stamp(path / name) for name in ("spack.yaml", "spack.lock"))
    return _source_digest(str(path), stamps)


@lru_cache(maxsize=128)
def _source_digest(path, stamps):
    digest = hashlib.sha256()
    for name in ("spack.yaml", "spack.lock"):
        digest.update(name.encode())
        digest.update((Path(path) / name).read_bytes())
    return digest.hexdigest()


def atomic_write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(data, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o664)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def validate(manifest, system=None, prefix=None, environments=(), published=True):
    require(manifest.get("schema_version") == SCHEMA_VERSION,
            "Unsupported manifest schema; regenerate with scripts/publish_spack_install_manifest.sh")
    require(manifest.get("status") in ("pending", "complete") and
            (not published or manifest["status"] == "complete"), "Manifest is not published")
    require(not system or manifest["system"] == system, "Manifest system does not match")
    require(not prefix or Path(manifest["install_prefix"]) == Path(prefix).absolute(),
            "Manifest install prefix does not match")
    sources = manifest["sources"]
    require(set(environments) <= set(sources), "Manifest is missing requested environments")
    require(not environments or set(environments) == set(sources),
            "Manifest contains environments outside the requested deployment")
    for name, source in sources.items():
        require(source["digest"], "Manifest snapshot is unfinished: " + name)
        require(source_digest(source["path"]) == source["digest"],
                "Manifest source has changed: " + name)
    if manifest["status"] == "pending":
        require(not manifest["packages"], "Pending manifest cannot record installed packages")
        return manifest
    packages = manifest["packages"]
    require(packages, "Manifest has no installed packages")
    paths, names = set(), set()
    expected, public = {}, set()
    for name, source in sources.items():
        require(set(source["roots"]) <= set(source["installed_hashes"]),
                "Source public roots are not all installed: " + name)
        public.update(source["roots"])
        for node_hash in source["installed_hashes"]:
            expected.setdefault(node_hash, set()).add(name)
    require(set(packages) == set(expected),
            "Packages do not exactly match installed source specs")
    require({key for key, package in packages.items() if package["public"]} == public,
            "Public modules do not exactly match intended source roots")
    for node_hash, package in packages.items():
        require(package["hash"] == node_hash, "Package hash does not match its inventory key")
        require(set(package["sources"]) == expected[node_hash],
                "Package has incorrect source membership: " + node_hash)
        require(all(isinstance(package[field], bool) for field in ("public", "external", "upstream")),
                "Package flags must be boolean")
        require(package["prefix"] is not None or package["external"],
                "Only external packages may omit their prefix")
        has_module = package["module_path"] is not None
        require(not package["public"] or has_module, "Public package has no module: " + node_hash)
        require(all(bool(package[field]) if has_module else package[field] is None
                    for field in ("module_path", "module_name", "scope")), "Incomplete module metadata")
        if has_module:
            key = (package["scope"], package["module_name"])
            require(package["module_path"] not in paths and key not in names,
                    "Manifest contains conflicting module identities")
            paths.add(package["module_path"])
            names.add(key)
        for dependency in package["autoloads"]:
            if dependency.get("hash"):
                target = packages.get(dependency["hash"], {})
                require(target.get("module_path") and
                        all(dependency[field] == target[field]
                            for field in ("module_name", "module_path")),
                        "Autoload does not match an installed package")
        if package["prefix"] is not None:
            require(Path(package["prefix"]).is_dir(), "Missing prefix: " + package["prefix"])
        for entry in [package] + package["autoloads"]:
            if entry.get("module_path"):
                require(Path(entry["module_path"]).is_file(),
                        "Missing module: " + entry["module_path"])
    return manifest


def get_manifest_path():
    override = os.getenv("SPACK_INSTALL_MANIFEST")
    prefix = os.getenv("INSTALL_PREFIX")
    return override or (str(Path(prefix) / "installation_metadata" / MANIFEST_FILE)
                        if prefix else None)


@lru_cache(maxsize=1)
def _read_manifest(path, stamp, system, prefix):
    with open(path, encoding="utf-8") as stream:
        return validate(json.load(stream), system, prefix)


def clear_manifest_cache():
    _read_manifest.cache_clear()


def get_manifest():
    path = get_manifest_path()
    if path and Path(path).name == ".concretization-only":
        return None
    require(path and Path(path).is_file(), "A published deployment inventory is required")
    manifest = _read_manifest(path, file_stamp(path), os.getenv("SYSTEM"), os.getenv("INSTALL_PREFIX"))
    for name, source in manifest["sources"].items():
        require(source_digest(source["path"]) == source["digest"],
                "Manifest source has changed: " + name)
    return manifest


def get_modules():
    manifest = get_manifest()
    if manifest is None:
        return []
    environment = os.getenv("SPACK_ENV")
    require(not environment or environment in manifest["sources"],
            "Manifest has no environment " + str(environment))
    return [entry for node_hash, entry in manifest["packages"].items()
            if entry["public"] and
            (not environment or node_hash in manifest["sources"][environment]["roots"])]


def get_module(module_path):
    for entry in get_modules():
        if entry["module_path"] == module_path:
            return entry
    raise ValueError("Not an intended public module: " + module_path)


def get_module_paths():
    return sorted(entry["module_path"] for entry in get_modules())


def get_module_dependencies(module_path):
    return [entry["module_path"] for entry in get_module(module_path)["autoloads"]
            if entry.get("module_path")]


def get_module_name(module_path):
    return get_module(module_path)["module_name"]


def get_library_path(module_path):
    return get_module(module_path)["prefix"]


def get_expected_autoloads(module_path):
    return [entry["module_name"] for entry in get_module(module_path)["autoloads"]]


def module_identity_commands(module_path):
    """Check actual loaded files, independently of generated Lua contents."""
    module = get_module(module_path)
    commands = []
    for entry in [module] + module["autoloads"]:
        if entry.get("module_path"):
            expected = shlex.quote(":" + entry["module_path"] + ":")
            commands.append(
                'case ":${_LMFILES_:-}:" in *' + expected + '*) ;; '
                '*) echo "Unexpected loaded modulefile" >&2; exit 1 ;; esac'
            )
    # Both systems' modules.yaml sets this variable for every package.
    variable = "PAWSEY_" + module["name"].upper().replace("-", "_") + "_HOME"
    if module["prefix"] is not None:
        commands.append('test "$(printenv ' + shlex.quote(variable) + ')" = ' +
                        shlex.quote(module["prefix"]) +
                        ' || { echo "Unexpected installation prefix" >&2; exit 1; }')
    commands.append("echo " + shlex.quote("manifest module verified: " + module["hash"]))
    return commands
