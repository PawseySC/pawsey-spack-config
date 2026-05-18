#!/bin/bash

# Pawsey compilation environment
STACK_VERSION=2025.08
COMPILER=gcc
COMPILER_VERSION=14.2.0

PROGRAM_NAME=pshell
PROGRAM_VERSION=1.2.1

# Architectures to build for
ARCH_LIST=("zen2" "zen3")

cd "$MYSCRATCH/setonix/2025.08"

# Download source once
if [ ! -f "v${PROGRAM_VERSION}.tar.gz" ]; then
    wget "https://github.com/PawseySC/pshell/archive/refs/tags/v${PROGRAM_VERSION}.tar.gz"
fi

# Extract once
if [ ! -d "pshell-${PROGRAM_VERSION}" ]; then
    tar -xvf "v${PROGRAM_VERSION}.tar.gz"
fi

for ARCH in "${ARCH_LIST[@]}"; do

    OSARCH="linux-sles15-${ARCH}"

    echo "========================================"
    echo "Building for ARCH=${ARCH}"
    echo "OSARCH=${OSARCH}"
    echo "========================================"

    # For system installation
    INSTALL_DIR_PREFIX="/software/setonix/${STACK_VERSION}/software/${OSARCH}/${COMPILER}-${COMPILER_VERSION}/${PROGRAM_NAME}-${PROGRAM_VERSION}"
    MODULEFILE_DIR="/software/setonix/${STACK_VERSION}/modules/${ARCH}/${COMPILER}/${COMPILER_VERSION}/utilities/${PROGRAM_NAME}"

    # For local installation (optional)
    # INSTALL_DIR_PREFIX="$MYSOFTWARE/setonix/${STACK_VERSION}/software/${OSARCH}/${COMPILER}-${COMPILER_VERSION}/${PROGRAM_NAME}-${PROGRAM_VERSION}"
    # MODULEFILE_DIR="$MYSOFTWARE/setonix/${STACK_VERSION}/modules/${ARCH}/${COMPILER}/${COMPILER_VERSION}/${PROGRAM_NAME}"

    mkdir -p "${INSTALL_DIR_PREFIX}/bin"
    mkdir -p "${MODULEFILE_DIR}"

    cd "$MYSCRATCH/setonix/2025.08/pshell-${PROGRAM_VERSION}"

    # Clean previous build if needed
    rm -rf release

    ./build_release

    cp release/pshell "${INSTALL_DIR_PREFIX}/bin"
    chmod a+rx "${INSTALL_DIR_PREFIX}/bin/pshell"

    # Create modulefile
    cat > "${MODULEFILE_DIR}/${PROGRAM_VERSION}.lua" << EOF
-- Modulefile for ${PROGRAM_NAME}

local root_dir = '${INSTALL_DIR_PREFIX}'

if (mode() ~= 'whatis') then
    prepend_path('PATH', root_dir .. '/bin')
    setenv('PAWSEY_PSHELL_HOME', '${INSTALL_DIR_PREFIX}')
end

-- Enforce explicit usage of versions by requiring full module name
if (mode() == 'load') then
    if (myModuleUsrName() ~= myModuleFullName()) then
        LmodError(
            'Default module versions are disabled by your systems administrator.\\n\\n',
            '\\tPlease load this module as <name>/<version>.\\n'
        )
    end
end
EOF

    echo "Installed ${PROGRAM_NAME}/${PROGRAM_VERSION} for ${ARCH}"

done

echo "All builds completed successfully."
