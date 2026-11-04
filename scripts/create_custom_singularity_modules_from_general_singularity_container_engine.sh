#!/bin/bash -e
set -o pipefail

# This script generates user-facing singularity modules from one rendered
# singularityce base module. It keeps the original flavour transformations while
# exposing an explicit interface for the wrapper workflow who is now controlling the
# generation of multiple versions and flavours of Singularity modules.

#
usage() {
    cat <<'USAGE'
Usage: create_custom_singularity_modules_from_general_singularity_container_engine.sh \
  --input-dir DIR --output-dir DIR --version VERSION --flavour FLAVOUR [--suffix LABEL]

  --input-dir DIR   Directory containing rendered base modules (<version>.lua).
  --output-dir DIR  Destination directory for generated custom variants.
  --version VERSION Base module version to transform.
  --flavour NAME    One of: nompi, mpi, mpi-gpu, askap, askap-gpu, nohost, slurm.
  --suffix LABEL    Optional label appended to generated module names.
USAGE
}

input_dir=""
output_dir=""
version=""
flavour=""
suffix=""
# Parse CLI.
while [ "$#" -gt 0 ]; do
    case "$1" in
        --input-dir|--output-dir|--version|--flavour|--suffix)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                printf 'ERROR: Missing value for %s\n' "$1" >&2
                exit 2
            fi
            case "$1" in
                --input-dir) input_dir=$2 ;;
                --output-dir) output_dir=$2 ;;
                --version) version=$2 ;;
                --flavour) flavour=$2 ;;
                --suffix) suffix=$2 ;;
            esac
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'ERROR: Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# Validate arguments.
if [ -z "$input_dir" ] || [ -z "$output_dir" ] || [ -z "$version" ] || [ -z "$flavour" ]; then
    usage >&2
    exit 2
fi
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || {
    printf 'ERROR: Invalid module version: %s\n' "$version" >&2
    exit 2
}
[[ "$suffix" =~ ^$|^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || {
    printf 'ERROR: Invalid suffix: %s\n' "$suffix" >&2
    exit 2
}
case "$flavour" in
    nompi|mpi|mpi-gpu|askap|askap-gpu|nohost|slurm) ;;
    *) printf 'ERROR: Unsupported flavour: %s\n' "$flavour" >&2; exit 2 ;;
esac

source_modulefile="$input_dir/$version.lua"
if [ ! -f "$source_modulefile" ] || [ -L "$source_modulefile" ]; then
    printf 'ERROR: Expected a regular rendered base module: %s\n' "$source_modulefile" >&2
    exit 1
fi

mkdir -p "$output_dir"
output_modulefile="$output_dir/$version-$flavour${suffix:+-$suffix}.lua"

# Original flavour model (one flavour generated per invocation):
# 1. Create one of several variants with different default behaviour:
#    A.1 singularity/x.x.x-mpi : injects all necessary libraries to run MPI, binds filesystems /scratch, /software
#    A.2 singularity/x.x.x-mpi-gpu : injects all necessary libraries to run MPI, binds filesystems /scratch, /software, etc and also preloads the gtl library and sets the MPICH variable to enable GPU-GPU MPI.
#    B. singularity/x.x.x-nompi : binds filesystems, also sets LD path based on currenty LD path
#    C.1 singularity/x.x.x-askap : like MPI but also addes /askapbuffer and also adds slurm related bind mounts
#    C.2 singularity/x.x.x-askap-gpu : like MPI but also addes /askapbuffer and also adds slurm related bind mounts
#    D. singularity/x.x.x-nohost : nothing from the host is injected, does mount file systems
#    E. singularity/x.x.x-slurm : like nompi but also mounts directories related to running slurm in a container
#
# The caller wrapper selects one flavour at a time; the transformations below preserve
# the original sed expressions for each flavour.
case "$flavour" in
    # 1.A.1 singularity-mpi also removes GPUMPI block
    mpi)
        sed \
            -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
            -e '/^-- add SLURM START/,/^-- add SLURM END/{/^-- add SLURM START/!{/^-- add SLURM END/!d}}' \
            -e '/^-- add GPUMPI START/,/^-- add GPUMPI END/{/^-- add GPUMPI START/!{/^-- add GPUMPI END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
    # 1.A.2 singularity-mpi-gpu removes /askapbuffer and Slurm block
    mpi-gpu)
        sed \
            -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
            -e '/^-- add SLURM START/,/^-- add SLURM END/{/^-- add SLURM START/!{/^-- add SLURM END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
    # 1.B singularity-nompi removes MPI, Slurm, and GPUMPI blocks
    nompi)
        sed \
            -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
            -e '/^-- add MPI START/,/^-- add MPI END/{/^-- add MPI START/!{/^-- add MPI END/!d}}' \
            -e '/^-- add SLURM START/,/^-- add SLURM END/{/^-- add SLURM START/!{/^-- add SLURM END/!d}}' \
            -e '/^-- add GPUMPI START/,/^-- add GPUMPI END/{/^-- add GPUMPI START/!{/^-- add GPUMPI END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
    # 1.C.1 singularity-askap keeps Slurm but removes GPUMPI lines
    askap)
        sed \
            -e '/^-- add GPUMPI START/,/^-- add GPUMPI END/{/^-- add GPUMPI START/!{/^-- add GPUMPI END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
    # 1.C.2 singularity-askap-gpu is just the original module
    askap-gpu)
        cp -p -- "$source_modulefile" "$output_modulefile"
        ;;
    # 1.D singularity-nohost removes host injections and host LD path wiring
    nohost)
        sed \
            -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
            -e '/^-- add MPI START/,/^-- add MPI END/{/^-- add MPI START/!{/^-- add MPI END/!d}}' \
            -e '/^-- add SLURM START/,/^-- add SLURM END/{/^-- add SLURM START/!{/^-- add SLURM END/!d}}' \
            -e '/^-- add GPUMPI START/,/^-- add GPUMPI END/{/^-- add GPUMPI START/!{/^-- add GPUMPI END/!d}}' \
            -e '/^-- add CRAY_PATHS START/,/^-- add CRAY_PATHS END/{/^-- add CRAY_PATHS START/!{/^-- add CRAY_PATHS END/!d}}' \
            -e '/^-- add CURRENT_HOST_LD_PATH START/,/^-- add CURRENT_HOST_LD_PATH END/{/^-- add CURRENT_HOST_LD_PATH START/!{/^-- add CURRENT_HOST_LD_PATH END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
    # 1.E singularity-slurm removes MPI and GPUMPI but keeps Slurm mounts
    slurm)
        sed \
            -e '/singularity_bindpath *=/ s;/askapbuffer;;g' \
            -e '/^-- add MPI START/,/^-- add MPI END/{/^-- add MPI START/!{/^-- add MPI END/!d}}' \
            -e '/^-- add GPUMPI START/,/^-- add GPUMPI END/{/^-- add GPUMPI START/!{/^-- add GPUMPI END/!d}}' \
            "$source_modulefile" > "$output_modulefile"
        ;;
esac

# Module variants must not pull dependency loads implicitly.
sed -i '/^load("/d' "$output_modulefile"
