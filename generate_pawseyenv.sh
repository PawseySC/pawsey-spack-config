#!/bin/bash -e
# Generate pawseyenv_<system>.lua in the current directory.
# Usage: ./generate_pawseyenv.sh [system] (default: setonix-q)

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export SYSTEM="${1:-${SYSTEM:-setonix-q}}"
export DATE_TAG="${DATE_TAG:-$(date +%Y.%m)}"
if [ -z "${INSTALL_PREFIX+x}" ] && [ -z "${BASE_INSTALL_DIR+x}" ]; then
  export INSTALL_PREFIX="/software/${SYSTEM}/${DATE_TAG}"
fi
export INSTALL_GROUP="${INSTALL_GROUP:-$(id -gn)}"

exec "${scriptdir}/scripts/generate_pawseyenv.sh" "${PWD}/pawseyenv_${SYSTEM}.lua"
