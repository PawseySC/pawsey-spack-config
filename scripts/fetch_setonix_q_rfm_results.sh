#!/bin/bash

set -euo pipefail

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
project_root=$( cd -- "${scriptdir}/.." &> /dev/null && pwd )

remote_host="${REMOTE_HOST:-edric_matwiejew@setonix.pawsey.org.au}"
remote_dir="${REMOTE_DIR:-/scratch/pawsey0001/setonix-q/2026.08/rfm_results}"
dry_run=0
delete_extra=0

function resolve_dest_dir()
{
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *)  printf '%s/%s\n' "${project_root}" "$1" ;;
    esac
}

dest_dir=$(resolve_dest_dir "${DEST_DIR:-setonix-q-2026.08-rfm_results}")

function usage()
{
    cat <<EOF
Usage: $(basename "$0") [options]

Transfer the contents of Setonix-Q RFM results into a project-root folder.

Defaults:
  remote host: ${remote_host}
  remote dir:  ${remote_dir}
  dest dir:    ${dest_dir}

Options:
  -d, --dest DIR       Destination directory. Relative paths are resolved from
                      the project root.
  -r, --remote HOST    SSH host, including username if needed.
  -s, --source DIR     Remote source directory.
  -n, --dry-run        Show what would be transferred without copying files.
      --delete         Mirror the remote directory by deleting local files that
                      are not present on the remote.
  -h, --help           Show this help text.

Environment overrides:
  REMOTE_HOST, REMOTE_DIR, DEST_DIR

Examples:
  $(basename "$0")
  $(basename "$0") --dry-run
  $(basename "$0") --dest rfm_results
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dest)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            dest_dir=$(resolve_dest_dir "$2")
            shift 2
            ;;
        -r|--remote)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            remote_host="$2"
            shift 2
            ;;
        -s|--source)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for $1" >&2
                exit 2
            fi
            remote_dir="$2"
            shift 2
            ;;
        -n|--dry-run)
            dry_run=1
            shift
            ;;
        --delete)
            delete_extra=1
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

if ! command -v rsync > /dev/null 2>&1; then
    echo "rsync is required but was not found in PATH." >&2
    exit 1
fi

mkdir -p "${dest_dir}"

rsync_opts=(
    -a
    --partial
    --human-readable
    --info=progress2
)

if [ "${dry_run}" -eq 1 ]; then
    rsync_opts+=(--dry-run)
fi

if [ "${delete_extra}" -eq 1 ]; then
    rsync_opts+=(--delete)
fi

echo "Remote: ${remote_host}:${remote_dir}/"
echo "Local:  ${dest_dir}/"

rsync "${rsync_opts[@]}" -e ssh "${remote_host}:${remote_dir}/" "${dest_dir}/"
