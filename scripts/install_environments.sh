#!/bin/bash -e

check_installation_environment
set_spack_config_repo
set_compilation_sets_for_arch
set_modulepaths_for_arch

#setup spack env variables
. "${INSTALL_PREFIX}/spack/share/spack/setup-env.sh"

# module load cpe/25.03
# module load gcc-native/14.2
# module use ${INSTALL_PREFIX}/staff_modulefiles
# # we need the python module to be available in order to run spack
# module --ignore-cache load pawseyenv/${pawseyenv_version}
# # swap is needed for the pawsey_temp module to work
# #module swap PrgEnv-gnu PrgEnv-cray
# #module swap PrgEnv-cray PrgEnv-gnu
# module use $INSTALL_PREFIX/modules/zen3/gcc/14.2.0/programming-languages
# module load spack/${spack_version}

# We are forced to install openblas outside an environment on Setonix because
# its build fails in a nondeterministic way. Setonix-Q environments select the
# desired OpenBLAS compiler/version explicitly, so do not pre-install it here.
if [ "${SYSTEM}" = "setonix" ]; then
  openblas_not_installed=1
  counter=0
  while (( openblas_not_installed > 0 ));
  do
    if (( counter > 5 )); then
      echo "Tried to install openblas 5 times, and it didn't work. Stopping here.."
      exit 1
    fi
    spack spec ${SPACK_SPEC_ARGS} openblas@0.3.24 %${main_compiler} threads=openmp
    if sg $INSTALL_GROUP -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} openblas@0.3.24 %${main_compiler} threads=openmp"; then
      openblas_not_installed=0
    else
      openblas_not_installed=$?
    fi
    (( counter = counter + 1 ))
  done
fi

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

ensure_spack_install_manifest_run

# Receipts are source-scoped and replaced on each run.  Reset every active
# environment before installing any of them so a failed rerun cannot later
# assemble a mixture of old and new roots.
for env in $env_list $cray_env_list; do
  reset_spack_install_receipt environment "${env}"
done

echo "Running installation with $NCPUS cores.."

for env in $env_list; do
  build_environment "${envdir}" "${env}" || exit 1
done

# instead of having a separate script for cray environments, just
# append them to the list of env but have a separate variable
# so can do a parallel build. 
for env in $cray_env_list; do
  build_environment "${envdir}" "${env}" || exit 1
done

# Assemble and publish only from the receipts produced by this deployment.
# The publication stage is shared with separately installed environments such
# as Setonix ROCm so they extend the same authoritative manifest.
deployment_environments=($env_list $cray_env_list)
"${PAWSEY_SPACK_CONFIG_REPO}/scripts/publish_spack_install_manifest.sh" \
  "${deployment_environments[@]}" || exit 1

# Remove .llvm from module files to stop it replacing gcc/cce at module load which breaks reframe tests
# Done post-installation, so commented out here
#grep -Elr "^load\(.*\.llvm.*\)" ${INSTALL_PREFIX}/modules | xargs sed -i "s/\(load(.*llvm.*)\)/--\1/"

# Generate commands for sysadmins to execute to fix Singularity permissions.
echo """Singularity fix permissions:
-----------------------------
Ask the admins to execute the following scripts:
"""
for prefix in `spack find -x --format "{prefix}" singularityce`; do echo ${prefix}/bin/spack_perms_fix.sh; done;
