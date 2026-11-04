#!/bin/bash
# Shared deployment inventory helpers for the installation scripts.

function spack_install_manifest_tool()
{
    echo "${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_manifest/cli.py"
}

function invalidate_spack_install_manifest()
{
    [ "${SYSTEM}" = "setonix-q" ] || [ "${SYSTEM}" = "ella" ] || return 0
    "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" invalidate \
        --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}" \
        --manifest "${SPACK_INSTALL_MANIFEST}"
}

function snapshot_spack_environment()
{
    export module_cat_list
    spack -E python "$(spack_install_manifest_tool)" snapshot \
        --install-prefix "${INSTALL_PREFIX}" --system "${SYSTEM}" \
        --manifest "${SPACK_INSTALL_MANIFEST}" \
        --source "$1"
}

function cleanup_spack_installation()
{
    if [ -z "${1:-}" ]; then
        echo "Usage: cleanup_spack_installation MANIFEST [--apply]" >&2
        return 1
    fi
    local manifest="$1"
    shift
    spack -E python "$(spack_install_manifest_tool)" cleanup --manifest "${manifest}" "$@"
}

export -f spack_install_manifest_tool
export -f invalidate_spack_install_manifest
export -f snapshot_spack_environment
export -f cleanup_spack_installation
