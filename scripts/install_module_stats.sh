#!/bin/bash -e
# 
# The module-stats package allows Pawsey staff to query the Graylog database about modules loaded on Setonix.
# The source code for the package is hosted on the Pawsey gitlab service, under Cristian's account. May be relocated in the future.
#
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

# Clone the repo directly in the installation path
STATS_INSTALL_DIR="${USER_PERMANENT_FILES_PREFIX}/pawsey0001/${SYSTEM}/${DATE_TAG}/software"
STATS_MODULE_DIR="${USER_PERMANENT_FILES_PREFIX}/pawsey0001/${SYSTEM}/${DATE_TAG}/modules/zen3/gcc/$gcc_version/module-stats"

PYTHON_MODULE=${python_name}/${python_version}
PYTHON_MAJOR=${python_version%.*}
mkdir -p "$STATS_INSTALL_DIR"
mkdir -p "$STATS_MODULE_DIR"
cd "$STATS_INSTALL_DIR"
# Requires access to Pawsey gitlab
[ -e module-stats ] || git clone ssh://git@gitlab.pawsey.org.au:2224/cdipietrantonio/module-logging.git module-stats 
cd module-stats
module load $PYTHON_MODULE
module load py-pip/${pip_version}-py${python_version}

pip3 install --prefix=$STATS_INSTALL_DIR/module-stats chardet charset_normalizer requests 
# generate module file
echo """
-- Modulefile for module-stats 
local root_dir = '$STATS_INSTALL_DIR/module-stats'
if (mode() ~= 'whatis') then
    load('$PYTHON_MODULE')
	prepend_path('PATH', root_dir)
	prepend_path('PYTHONPATH', root_dir .. '/lib/python$PYTHON_MAJOR/site-packages')
end
""" > $STATS_MODULE_DIR/master.lua


