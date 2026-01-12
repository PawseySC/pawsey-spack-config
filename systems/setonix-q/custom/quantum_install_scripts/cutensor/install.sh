#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use.sh
. $script_dir/../utils.sh

# Parse arguments
parse_args "$@"

# Install software (skip if --module-only)
if should_install_software; then
    echo "Installing ${tool_name}/${tool_ver}"
    set_dependencies
    setup_build_dir
    download_archive "${cutensor_archive}.tar.xz" "${cutensor_url}"
    extract_archive "${cutensor_archive}.tar.xz"
    install_files "${cutensor_archive}"
    cleanup_build
fi

# Install module
finalize_install
