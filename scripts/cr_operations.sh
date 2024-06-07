#!/bin/bash
# Operations outlined in change requests (CRs) from 2024.05 deployment

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
. "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"

# Remove llvm load statements from affected modiule files
grep -Elr "^load\(.*\.llvm.*\)" ${INSTALL_PREFIX}/modules | xargs sed -i "s/\(load(.*llvm.*)\)/--\1/"

# Fix modules with '++' (boost and log4cxx variants)
find ${INSTALL_PREFIX}/modules -type f -name '*__*' -exec bash -c 'echo mv "$1" "${1//__/++}"' _ {} \;
# Fix hpl manually as the only module with a single '+' in module name
mv ${INSTALL_PREFIX}modules/zen3/gcc/12.2.0/benchmarking/hpl/2.3_openmp.lua ${INSTALL_PREFIX}modules/zen3/gcc/12.2.0/benchmarking/hpl/2.3+openmp.lua
