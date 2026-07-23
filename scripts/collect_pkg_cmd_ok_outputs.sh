#!/bin/bash

set -euo pipefail

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
project_root=$( cd -- "${scriptdir}/.." &> /dev/null && pwd )

yaml_file="${YAML_FILE:-${project_root}/systems/setonix-q/rfm_files/pkg_cmds.yaml}"
output_file="${OUTPUT_FILE:-${project_root}/setonix-q-pkg-cmd-ok-outputs.txt}"
load_modules=1
run_configured=1
run_probe=1
dry_run=0
timeout_seconds="${TIMEOUT_SECONDS:-120}"

function usage()
{
    cat <<EOF
Usage: $(basename "$0") [options]

Run every pkg_cmds.yaml entry whose expected output is exactly of the form
"<name> ok", and append the captured output to an organised report.

By default each package is run in a fresh subshell with module setup matching
the Setonix-Q baseline_sanity_check:
  module purge
  module load pawsey pawseytools
  module use \${INSTALL_PREFIX}/staff_modulefiles
  module load pawseyenv/\${DATE_TAG:-2026.08}
  module load PrgEnv-gnu
  module load <pkg_cmds key>

The report includes both:
  configured command: the exact command from pkg_cmds.yaml
  probe command:      a best-effort version with the final '&& echo "... ok"'
                      wrapper and common output suppression removed

Options:
  -y, --yaml FILE       pkg_cmds.yaml path.
  -o, --output FILE     Report file to append to.
      --no-module-load  Do not run module setup or package module loads.
      --configured-only Run only the exact configured commands.
      --probe-only      Run only the expanded probe commands.
  -t, --timeout SEC     Timeout per command. Use 0 to disable. Default: ${timeout_seconds}
  -n, --dry-run         List matching commands without running them.
  -h, --help            Show this help text.

Environment overrides:
  YAML_FILE, OUTPUT_FILE, TIMEOUT_SECONDS, INSTALL_PREFIX, DATE_TAG,
  pawseyenv_version
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -y|--yaml)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            yaml_file="$2"
            shift 2
            ;;
        -o|--output)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            output_file="$2"
            shift 2
            ;;
        --no-module-load)
            load_modules=0
            shift
            ;;
        --configured-only)
            run_configured=1
            run_probe=0
            shift
            ;;
        --probe-only)
            run_configured=0
            run_probe=1
            shift
            ;;
        -t|--timeout)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            timeout_seconds="$2"
            shift 2
            ;;
        -n|--dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ ! -f "${yaml_file}" ]; then
    echo "YAML file not found: ${yaml_file}" >&2
    exit 1
fi

if ! command -v python3 > /dev/null 2>&1; then
    echo "python3 is required to parse ${yaml_file}." >&2
    exit 1
fi

function matching_records()
{
    python3 - "${yaml_file}" <<'PY'
import re
import shlex
import sys

yaml_file = sys.argv[1]

def parse_single_quoted(text, start):
    out = []
    idx = start + 1
    while idx < len(text):
        char = text[idx]
        if char == "'":
            if idx + 1 < len(text) and text[idx + 1] == "'":
                out.append("'")
                idx += 2
                continue
            return "".join(out), idx + 1
        out.append(char)
        idx += 1
    raise ValueError("unterminated single-quoted scalar")

def parse_double_quoted(text, start):
    out = []
    idx = start + 1
    escapes = {
        "0": "\0",
        "a": "\a",
        "b": "\b",
        "t": "\t",
        "n": "\n",
        "v": "\v",
        "f": "\f",
        "r": "\r",
        "e": "\033",
        '"': '"',
        "\\": "\\",
        "/": "/",
    }
    while idx < len(text):
        char = text[idx]
        if char == "\\" and idx + 1 < len(text):
            idx += 1
            out.append(escapes.get(text[idx], text[idx]))
        elif char == '"':
            return "".join(out), idx + 1
        else:
            out.append(char)
        idx += 1
    raise ValueError("unterminated double-quoted scalar")

def parse_flow_list(text):
    text = text.strip()
    if not text.startswith("["):
        raise ValueError("expected flow-style list")

    idx = 1
    items = []
    while idx < len(text):
        while idx < len(text) and text[idx].isspace():
            idx += 1
        if idx >= len(text):
            break
        if text[idx] == "]":
            return items

        if text[idx] == "'":
            item, idx = parse_single_quoted(text, idx)
        elif text[idx] == '"':
            item, idx = parse_double_quoted(text, idx)
        else:
            start = idx
            while idx < len(text) and text[idx] not in ",]":
                idx += 1
            item = text[start:idx].strip()

        items.append(item)

        while idx < len(text) and text[idx].isspace():
            idx += 1
        if idx < len(text) and text[idx] == ",":
            idx += 1
            continue
        if idx < len(text) and text[idx] == "]":
            return items

    raise ValueError("unterminated flow-style list")

def parse_key(raw_key):
    raw_key = raw_key.strip()
    if raw_key.startswith("'"):
        key, end = parse_single_quoted(raw_key, 0)
        if raw_key[end:].strip():
            raise ValueError(f"unexpected text after quoted key: {raw_key!r}")
        return key
    if raw_key.startswith('"'):
        key, end = parse_double_quoted(raw_key, 0)
        if raw_key[end:].strip():
            raise ValueError(f"unexpected text after quoted key: {raw_key!r}")
        return key
    return raw_key

def load_pkg_cmds(path):
    data = {}
    category = None
    top_level_re = re.compile(r"^([A-Za-z0-9_-]+):\s*(?:#.*)?$")
    entry_re = re.compile(r"^\s{2}(.+?):\s*(\[.*\])\s*(?:#.*)?$")

    with open(path, "r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, start=1):
            stripped = line.strip()
            if not stripped or stripped == "---" or stripped.startswith("#"):
                continue

            top_match = top_level_re.match(line.rstrip())
            if top_match:
                category = top_match.group(1)
                data.setdefault(category, {})
                continue

            entry_match = entry_re.match(line.rstrip())
            if entry_match and category is not None:
                key = parse_key(entry_match.group(1))
                data[category][key] = parse_flow_list(entry_match.group(2))
                continue

            if line.startswith("  ") and stripped.startswith("#"):
                continue

            raise ValueError(f"unsupported YAML shape at {path}:{lineno}: {line.rstrip()}")

    return data

data = load_pkg_cmds(yaml_file)

def command_line(entry):
    exe = str(entry[0])
    opts = str(entry[1] or "")
    return f"{exe} {opts}".strip()

def strip_ok_probe(cmdline, expected):
    try:
        parts = shlex.split(cmdline)
    except ValueError:
        return cmdline

    if len(parts) < 3 or parts[0] != "bash" or parts[1] != "-lc":
        return cmdline

    script = parts[2].strip()
    expected_re = re.escape(expected)
    script = re.sub(
        rf"\s*&&\s*echo\s+(?:\"{expected_re}\"|'{expected_re}')\s*$",
        "",
        script,
    ).strip()
    script = re.sub(r"\s*(?:1?>)\s*/dev/null", "", script).strip()
    script = re.sub(r"\s*\|\s*grep\s+-[A-Za-z]*q[A-Za-z]*\s+[^|&;]+$", "", script).strip()

    if script == parts[2].strip():
        return cmdline

    return "bash -lc " + shlex.quote(script)

records = []
for category, entries in data.items():
    if not isinstance(entries, dict):
        continue
    for key, value in entries.items():
        if not isinstance(value, list) or len(value) < 3:
            continue
        expected = value[2]
        if not isinstance(expected, str):
            continue
        if not re.fullmatch(r"[^\s]+ ok", expected):
            continue
        configured = command_line(value)
        probe = strip_ok_probe(configured, expected)
        records.append((category, key, expected, configured, probe))

for record in records:
    print("\t".join(record))
PY
}

function run_shell_command()
{
    local cmdline="$1"

    if [ "${timeout_seconds}" = "0" ] || ! command -v timeout > /dev/null 2>&1; then
        bash -o pipefail -c "${cmdline}"
    else
        timeout "${timeout_seconds}" bash -o pipefail -c "${cmdline}"
    fi
}

function run_module_setup()
{
    local module_name="$1"
    local date_tag="${DATE_TAG:-${pawseyenv_version:-2026.08}}"

    if ! command -v module > /dev/null 2>&1; then
        echo "module command not found"
        return 1
    fi

    echo "\$ module purge"
    module purge
    echo "\$ module load pawsey pawseytools"
    module load pawsey pawseytools

    if [ -n "${INSTALL_PREFIX:-}" ]; then
        echo "\$ module use ${INSTALL_PREFIX}/staff_modulefiles"
        module use "${INSTALL_PREFIX}/staff_modulefiles"
    else
        echo "INSTALL_PREFIX is not set; skipping module use for staff_modulefiles"
    fi

    echo "\$ module load pawseyenv/${date_tag}"
    module load "pawseyenv/${date_tag}"
    echo "\$ module load PrgEnv-gnu"
    module load PrgEnv-gnu
    echo "\$ module load ${module_name}"
    module load "${module_name}"
}

record_count=$(matching_records | wc -l | awk '{print $1}')

if [ "${dry_run}" -eq 1 ]; then
    echo "YAML: ${yaml_file}"
    echo "Matching '<name> ok' entries: ${record_count}"
    matching_records | awk -F '\t' '{printf "%3d  %s/%s  expected=%s\n     configured: %s\n     probe:      %s\n", NR, $1, $2, $3, $4, $5}'
    exit 0
fi

mkdir -p "$(dirname "${output_file}")"

{
    echo "# pkg_cmds.yaml ok-output capture"
    echo "run_started: $(date -Iseconds)"
    echo "host: $(hostname)"
    echo "yaml_file: ${yaml_file}"
    echo "matching_entries: ${record_count}"
    echo "load_modules: ${load_modules}"
    echo "run_configured: ${run_configured}"
    echo "run_probe: ${run_probe}"
    echo "timeout_seconds: ${timeout_seconds}"
    echo
} >> "${output_file}"

index=0
while IFS=$'\t' read -r category pkg_key expected configured_cmd probe_cmd; do
    index=$((index + 1))

    {
        echo "================================================================================"
        echo "entry: ${index}/${record_count}"
        echo "category: ${category}"
        echo "package_key: ${pkg_key}"
        echo "expected: ${expected}"
        echo "configured_command: ${configured_cmd}"
        echo "probe_command: ${probe_cmd}"
        echo "started: $(date -Iseconds)"
        echo
    } >> "${output_file}"

    (
        set +e

        if [ "${load_modules}" -eq 1 ]; then
            echo "--- module setup begin ---"
            run_module_setup "${pkg_key}"
            module_status=$?
            echo "--- module setup end (exit=${module_status}) ---"
            echo
        fi

        if [ "${run_configured}" -eq 1 ]; then
            echo "--- configured command output begin ---"
            echo "\$ ${configured_cmd}"
            run_shell_command "${configured_cmd}"
            configured_status=$?
            echo "--- configured command output end (exit=${configured_status}) ---"
            echo
        fi

        if [ "${run_probe}" -eq 1 ] && { [ "${run_configured}" -eq 0 ] || [ "${probe_cmd}" != "${configured_cmd}" ]; }; then
            echo "--- probe command output begin ---"
            echo "\$ ${probe_cmd}"
            run_shell_command "${probe_cmd}"
            probe_status=$?
            echo "--- probe command output end (exit=${probe_status}) ---"
            echo
        elif [ "${run_probe}" -eq 1 ]; then
            echo "--- probe command skipped: identical to configured command ---"
            echo
        fi
    ) >> "${output_file}" 2>&1

    {
        echo "finished: $(date -Iseconds)"
        echo
    } >> "${output_file}"
done < <(matching_records)

{
    echo "run_finished: $(date -Iseconds)"
    echo
} >> "${output_file}"

echo "Appended ${record_count} entries to ${output_file}"
