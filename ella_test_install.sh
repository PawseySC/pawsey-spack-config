# Test install script for the pawsey-spack-config ella-setup branch

export DATE_TAG=2024.06
export SYSTEM=ella

export PAWSEY_PROJECT=pawsey0001

# .pawsey_project is not sourced on ella
if [ -z "${MYSOFTWARE}" ]; then
	export MYSOFTWARE="/pawsey/software/projects/$PAWSEY_PROJECT/$USER"
fi

if [ -z "${PAWESY_PROJECT}" ]; then
	export PAWSEY_PROJECT=pawsey0001
fi

if [ -z "${INSTALL_GROUP}" ]; then
	export INSTALL_GROUP=$PAWSEY_PROJECT
fi

# Create directory for Spack install, see below.
export ACTUAL_INSTALL_PREFIX="/pawsey/software/projects/${PAWSEY_PROJECT}/${USER}/spack-${DATE_TAG}"
mkdir -p $ACTUAL_INSTALL_PREFIX

# Installing in a deep directory caused a shebang error.
# Using a symlink in the user home directory a workaround.
export INSTALL_PREFIX="/home/${USER}/spack-${DATE_TAG}"
if [ ! -L "${INSTALL_PREFIX}" ]; then
	    ln -s "$ACTUAL_INSTALL_PREFIX" "$INSTALL_PREFIX"
fi

. ./scripts/install_spack.sh
. ./scripts/install_python.sh
