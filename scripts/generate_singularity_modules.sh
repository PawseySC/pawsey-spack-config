#!/bin/bash
#
# Installation entry point: render all installed SingularityCE versions for the
# configured architecture/compiler, then generate the Pawsey variants.
set -e -o pipefail

PAWSEY_SPACK_CONFIG_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SYSTEM=${SYSTEM:-${PAWSEY_CLUSTER:?Set SYSTEM or PAWSEY_CLUSTER}}
export SYSTEM
set -a
# shellcheck source=/dev/null
. "$PAWSEY_SPACK_CONFIG_REPO/systems/$SYSTEM/settings.sh"
set +a
# shellcheck source=scripts/singularity_module_pipeline.sh
. "$PAWSEY_SPACK_CONFIG_REPO/scripts/singularity_module_pipeline.sh"

stack_prefix=$(realpath -e "$INSTALL_PREFIX")
mkdir -p "$stack_prefix/module-generation-runs"
run=$(mktemp -d "$stack_prefix/module-generation-runs/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
printf 'Module generation logs: %s\n' "$run"
psc_generate_singularity_modules "$stack_prefix" "$stack_prefix" "$run"
