#!/usr/bin/env python3
"""Collect Setonix-Q lockfiles and diagnostics for environment comparison."""

from __future__ import annotations

import argparse
import csv
import datetime
import json
import os
import platform
import shutil
import socket
import subprocess
import tarfile
import tempfile
from collections import defaultdict
from pathlib import Path


SYSTEM = "setonix-q"


def run(command, cwd):
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
    except OSError as error:
        return f"Could not run {command[0]}: {error}\n"
    return f"$ {' '.join(command)}\nexit_code={result.returncode}\n{result.stdout}"


def copy_path(source, destination_root, repo_root):
    if not source.exists():
        return
    destination = destination_root / source.relative_to(repo_root)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True)
    else:
        shutil.copy2(source, destination)


def write_tsv(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def compiler_text(node):
    compiler = node.get("compiler") or {}
    if isinstance(compiler, dict):
        name = compiler.get("name") or ""
        version = compiler.get("version") or ""
        return f"{name}@{version}" if name or version else ""
    return str(compiler)


def target_text(node):
    architecture = node.get("arch") or node.get("architecture") or {}
    if not isinstance(architecture, dict):
        return str(architecture)
    target = architecture.get("target") or {}
    if isinstance(target, dict):
        return str(target.get("name") or target.get("microarchitecture") or "")
    return str(target)


def analyse_lockfiles(environment_dir, report_dir):
    environments = []
    roots = []
    nodes = []
    membership = defaultdict(lambda: {"environments": set(), "roots": set()})
    by_name_version = defaultdict(lambda: defaultdict(lambda: {"environments": set(), "roots": set()}))

    lockfiles = sorted(environment_dir.glob("*/spack.lock"))
    for lockfile in lockfiles:
        environment = lockfile.parent.name
        try:
            with lockfile.open(encoding="utf-8") as stream:
                lock = json.load(stream)
        except (OSError, json.JSONDecodeError) as error:
            environments.append([environment, "ERROR", "", "", str(error)])
            continue

        metadata = lock.get("_meta") or {}
        concrete = lock.get("concrete_specs") or {}
        lock_roots = lock.get("roots") or []
        root_hashes = {item.get("hash") for item in lock_roots}
        environments.append(
            [
                environment,
                metadata.get("lockfile-version", ""),
                metadata.get("specfile-version", ""),
                len(lock_roots),
                len(concrete),
            ]
        )

        for item in lock_roots:
            node_hash = item.get("hash", "")
            node = concrete.get(node_hash) or {}
            roots.append(
                [
                    environment,
                    node_hash,
                    node.get("name", ""),
                    node.get("version", ""),
                    item.get("spec", ""),
                ]
            )

        for node_hash, node in concrete.items():
            name = node.get("name", "")
            version = node.get("version", "")
            is_root = node_hash in root_hashes
            parameters = node.get("parameters") or {}
            nodes.append(
                [
                    environment,
                    node_hash,
                    name,
                    version,
                    int(is_root),
                    compiler_text(node),
                    target_text(node),
                    json.dumps(parameters, sort_keys=True, separators=(",", ":")),
                ]
            )
            membership[node_hash]["environments"].add(environment)
            if is_root:
                membership[node_hash]["roots"].add(environment)
            group = by_name_version[(name, version)][node_hash]
            group["environments"].add(environment)
            if is_root:
                group["roots"].add(environment)

    duplicate_rows = []
    root_collision_rows = []
    for (name, version), hashes in sorted(by_name_version.items()):
        if len(hashes) < 2:
            continue
        for node_hash, data in sorted(hashes.items()):
            row = [
                name,
                version,
                len(hashes),
                node_hash,
                ",".join(sorted(data["environments"])),
                ",".join(sorted(data["roots"])),
            ]
            duplicate_rows.append(row)
            if data["roots"]:
                root_collision_rows.append(row)

    shared_rows = []
    node_identity = {
        row[1]: (row[2], row[3])
        for row in nodes
    }
    for node_hash, data in sorted(membership.items()):
        if len(data["environments"]) < 2:
            continue
        name, version = node_identity[node_hash]
        shared_rows.append(
            [
                node_hash,
                name,
                version,
                ",".join(sorted(data["environments"])),
                ",".join(sorted(data["roots"])),
            ]
        )

    write_tsv(
        report_dir / "environments.tsv",
        ["environment", "lockfile_version", "specfile_version", "roots", "nodes"],
        environments,
    )
    write_tsv(
        report_dir / "roots.tsv",
        ["environment", "hash", "name", "version", "requested_spec"],
        roots,
    )
    write_tsv(
        report_dir / "nodes.tsv",
        ["environment", "hash", "name", "version", "is_root", "compiler", "target", "parameters_json"],
        nodes,
    )
    write_tsv(
        report_dir / "duplicate_name_versions.tsv",
        ["name", "version", "hash_count", "hash", "environments", "root_environments"],
        duplicate_rows,
    )
    write_tsv(
        report_dir / "multiple_root_hashes.tsv",
        ["name", "version", "hash_count", "hash", "environments", "root_environments"],
        root_collision_rows,
    )
    write_tsv(
        report_dir / "shared_hashes.tsv",
        ["hash", "name", "version", "environments", "root_environments"],
        shared_rows,
    )
    return len(lockfiles), len(duplicate_rows), len(root_collision_rows)


def collect_spack_diagnostics(repo_root, environment_dir, output_dir):
    diagnostics = output_dir / "spack_diagnostics"
    diagnostics.mkdir(parents=True, exist_ok=True)
    spack = shutil.which("spack")
    if not spack:
        (diagnostics / "NOT_COLLECTED.txt").write_text(
            "The spack command was not available in PATH.\n", encoding="utf-8"
        )
        return False

    commands = {
        "version.txt": [spack, "--version"],
        "debug_report.txt": [spack, "debug", "report"],
        "installed_specs.txt": [spack, "find", "--json"],
        "packages.txt": [spack, "config", "get", "packages"],
        "concretizer.txt": [spack, "config", "get", "concretizer"],
        "modules.txt": [spack, "config", "get", "modules"],
        "upstreams.txt": [spack, "config", "get", "upstreams"],
    }
    for filename, command in commands.items():
        (diagnostics / filename).write_text(run(command, repo_root), encoding="utf-8")

    for environment in sorted(environment_dir.iterdir()):
        if not (environment / "spack.yaml").is_file():
            continue
        env_output = diagnostics / "environments" / environment.name
        env_output.mkdir(parents=True, exist_ok=True)
        for scope in ("packages", "concretizer", "modules"):
            command = [spack, "-e", str(environment), "config", "get", scope]
            (env_output / f"{scope}.txt").write_text(
                run(command, repo_root), encoding="utf-8"
            )
    return True


def parse_args():
    default_repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=default_repo)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--skip-spack-diagnostics",
        action="store_true",
        help="collect repository files and lockfile summaries only",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    repo_root = args.repo.resolve()
    system_dir = repo_root / "systems" / SYSTEM
    environment_dir = system_dir / "environments"
    if not environment_dir.is_dir():
        raise SystemExit(f"Setonix-Q environments do not exist: {environment_dir}")

    timestamp = datetime.datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
    output = (
        args.output.resolve()
        if args.output
        else Path.cwd() / f"setonix-q-environment-data-{timestamp}.tar.gz"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise SystemExit(f"Refusing to overwrite existing output: {output}")

    with tempfile.TemporaryDirectory(prefix="setonix-q-environment-data-") as temporary:
        staging = Path(temporary) / f"setonix-q-environment-data-{timestamp}"
        staging.mkdir()

        for source in (
            system_dir / "settings.sh",
            system_dir / "install_manifest.py",
        ):
            copy_path(source, staging, repo_root)
        for source in sorted((system_dir / "configs").rglob("*.yaml")):
            copy_path(source, staging, repo_root)
        for source in sorted((system_dir / "templates").rglob("*.lua")):
            copy_path(source, staging, repo_root)
        for pattern in ("spack.yaml", "spack.lock"):
            for source in sorted(environment_dir.rglob(pattern)):
                copy_path(source, staging, repo_root)

        install_prefix = os.environ.get("INSTALL_PREFIX")
        if install_prefix:
            metadata = Path(install_prefix) / "installation_metadata"
            runtime = staging / "runtime_installation_metadata"
            for filename in (
                "current_run.json",
                "spack_install_manifest.candidate.json",
                "spack_install_module_plan.tsv",
                "spack_install_manifest.json",
            ):
                source = metadata / filename
                if source.is_file():
                    runtime.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, runtime / filename)

        reports = staging / "reports"
        reports.mkdir()
        lock_count, duplicate_count, root_collision_count = analyse_lockfiles(
            environment_dir, reports
        )

        git_commands = {
            "git_head.txt": ["git", "rev-parse", "HEAD"],
            "git_branch.txt": ["git", "branch", "--show-current"],
            "git_status.txt": ["git", "status", "--short"],
            "git_diff.patch": ["git", "diff", "--no-ext-diff"],
        }
        for filename, command in git_commands.items():
            (reports / filename).write_text(run(command, repo_root), encoding="utf-8")

        spack_collected = False
        if not args.skip_spack_diagnostics:
            spack_collected = collect_spack_diagnostics(
                repo_root, environment_dir, staging
            )

        summary = (
            "Setonix-Q environment data collection\n"
            f"Generated: {datetime.datetime.now().astimezone().isoformat()}\n"
            f"Host: {socket.getfqdn()}\n"
            f"Platform: {platform.platform()}\n"
            f"Python: {platform.python_version()}\n"
            f"Repository: {repo_root}\n"
            f"Lockfiles found: {lock_count}\n"
            f"Rows in duplicate_name_versions.tsv: {duplicate_count}\n"
            f"Rows in multiple_root_hashes.tsv: {root_collision_count}\n"
            f"Spack diagnostics collected: {spack_collected}\n\n"
            "No environments were concretized or modified by this collector.\n"
        )
        (staging / "README.txt").write_text(summary, encoding="utf-8")

        with tarfile.open(output, "w:gz") as archive:
            archive.add(staging, arcname=staging.name)

    print(output)
    print(f"Copy it from the cluster with: scp {os.environ.get('USER', '<user>')}@{socket.getfqdn()}:{output} .")


if __name__ == "__main__":
    main()
