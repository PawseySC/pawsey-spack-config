#!/bin/bash

export script_dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
. $script_dir/use-cutensor-setonix-q.sh
. $script_dir/utils.sh

# Usage
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [--module-only]"
    echo "  --module-only  Skip software installation, only create/update module file"
    exit 0
fi

# install software (skip if --module-only)
if [[ "$1" != "--module-only" ]]; then 
    echo "Installing ${tool_name}/${tool_ver}"
    set_dependencies

    # Create build directory
    build_dir="$MYSCRATCH/${tool_name}-build"
    mkdir -p ${build_dir}
    cd ${build_dir}

    # Download if not present
    if [[ ! -f "${cutensor_archive}.tar.xz" ]]; then
        echo "Downloading cuTensor ${tool_ver}..."
        wget -q "${cutensor_url}"
    fi

    # Extract
    echo "Extracting..."
    tar -xf "${cutensor_archive}.tar.xz"

    # Install to destination
    echo "Installing to ${install_dir}..."
    mkdir -p "${install_dir}"
    cp -r ${cutensor_archive}/* "${install_dir}/"

    # Cleanup
    cd ${script_dir}
    rm -rf ${build_dir}

    echo "cuTensor installed to ${install_dir}"
fi

# install module (using cutensor-specific template)
install_module ${install_dir} ${tool_name} ${tool_ver} "${brief}" "${descrip}" "cutensor-sample.lua"

echo "cuTensor ${tool_ver} installation complete!"
