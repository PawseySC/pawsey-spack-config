#!/bin/bash 

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

module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module use $INSTALL_PREFIX/modules/zen3/gcc/13.3.0/programming-languages
module load spack/${spack_version}

nprocs="128"
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
sg $INSTALL_GROUP -c "spack install openblas@0.3.24 threads=openmp"
openblas_not_installed=$?
(( counter = counter + 1 ))
done

# list of environments included in variables.sh (sourced above)
envdir="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments"

echo "Running installation with $nprocs cores.."

for env in $env_list; do
  echo "Installing environment $env..."
  cd ${envdir}/${env}
  spack env activate ${envdir}/${env} 
  spack concretize -f
  if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
    sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs} --only dependencies"
  else
    sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs}"
  fi
  spack env deactivate
  cd -
done

for env in $cray_env_list; do
  echo "Installing environment $env..."
  cd ${envdir}/${env}
  spack env activate ${envdir}/${env}
  spack concretize -f
  sg $INSTALL_GROUP -c "spack install --no-checksum -j${nprocs}"
  spack env deactivate
  cd -
done

# Create binary cache
if [ ${SPACK_POPULATE_CACHE} -eq 1 ]; then
  for hash in `spack find -x --format "{hash}"`; do spack buildcache create -a -m systemwide_buildcache  /$hash; done;
fi
# Refresh module files - explicit specs
for hash in `spack find -x --format "{hash}"`; do spack module lmod refresh -y /$hash; done;

# Refresh dependencies - implicit specs (manually remove .llvm load from pocl modulefile)
for hash in `spack find -X --format "{hash}"`; do spack module lmod refresh -y /$hash; done;

# Remove .llvm from module files to stop it replacing gcc/cce at module load which breaks reframe tests
# Done post-installation, so commented out here
#grep -Elr "^load\(.*\.llvm.*\)" ${INSTALL_PREFIX}/modules | xargs sed -i "s/\(load(.*llvm.*)\)/--\1/"

# Generate commands for sysadmins to execute to fix Singularity permissions.
echo """Singularity fix permissions:
-----------------------------
Ask the admins to execute the following scripts:
"""
for prefix in `spack find -x --format "{prefix}" singularityce`; do echo ${prefix}/bin/spack_perms_fix.sh; done;
