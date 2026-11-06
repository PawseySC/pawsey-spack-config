#!/bin/bash -e

# Install the configured bootstrap environment before application environments.

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

set_spack_config_repo
check_installation_environment
bootstrap || exit 1
export SPACK_PYTHON="${SPACK_PYTHON:-${BOOTSTRAP_PYTHON:-python3}}"
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

if [ "${SPACK_POPULATE_CACHE}" -eq 1 ]; then
    spack gpg init
    spack gpg create Spack spack@pawsey.org.au
fi

bootstrap_envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"
spack -e "${bootstrap_envdir}/${bootstrap_environment}" concretize -f ${SPACK_CONCRETIZE_ARGS} || exit 1
snapshot_spack_environment "${bootstrap_envdir}/${bootstrap_environment}" || exit 1
build_environment "${bootstrap_envdir}" "${bootstrap_environment}" || exit 1
