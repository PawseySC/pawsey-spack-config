#!/bin/bash -e

scriptdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "${scriptdir}/pawsey_software_stack_funcs.sh"

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module use $INSTALL_PREFIX/modules/zen3/gcc/13.3.0/programming-languages
module load spack/${spack_version}

nprocs="64"
# We are forced to install openblas outside an environment because its build fails
# in a nondeterministic way. So we just keep trying.

openblas_not_installed=1
counter=0
while (( openblas_not_installed > 0 ));
do
if (( counter > 5 )); then
	echo "Tried to install openblas 5 times, and it didn't work. Stopping here.."
	exit 1
fi
if sg $INSTALL_GROUP -c "spack install openblas@0.3.24 threads=openmp"; then
	openblas_not_installed=0
else
	openblas_not_installed=$?
fi
(( counter = counter + 1 ))
done

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

echo "Running installation with $nprocs cores.."

#Run rocm env on a gpu node with craype-accel-amd-gfx90a loaded
reset_spack_install_receipt environment rocm
cd "${envdir}/rocm"
module load craype-accel-amd-gfx90a
spack env activate "${envdir}/rocm"
spack concretize -f
sg "${INSTALL_GROUP}" -c "spack install --no-checksum -j${nprocs}"
spack env deactivate
record_concretized_environment "${envdir}/rocm" rocm root
seal_spack_install_receipt environment rocm

# Extend the same active deployment manifest used by the main environment
# workflow, then republish modules and exact paths with ROCm included.
deployment_environments=($env_list $cray_env_list rocm)
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/publish_spack_install_manifest.sh" \
  "${deployment_environments[@]}"

# Remove .llvm from module files to stop it replacing gcc/cce at module load which breaks reframe tests
# Done post-installation, so commented out here
#grep -Elr "^load\(.*\.llvm.*\)" ${INSTALL_PREFIX}/modules | xargs sed -i "s/\(load(.*llvm.*)\)/--\1/"

# Generate commands for sysadmins to execute to fix Singularity permissions.
echo """Singularity fix permissions:
-----------------------------
Ask the admins to execute the following scripts:
"""
for prefix in `spack find -x --format "{prefix}" singularityce`; do echo ${prefix}/bin/spack_perms_fix.sh; done;
