#!/bin/bash -e

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

# spack module
module use ${INSTALL_PREFIX}/staff_modulefiles
# we need the python module to be available in order to run spack
module --ignore-cache load pawseyenv/${pawseyenv_version}
# swap is needed for the pawsey_temp module to work
module swap PrgEnv-gnu PrgEnv-cray
module swap PrgEnv-cray PrgEnv-gnu
module load spack/${spack_version}


# original environment yaml
original_env_yaml="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/environments/python/spack.yaml"
# directory to create derivative yaml for the view
view_env_dir="${PAWSEY_SPACK_CONFIG_REPO}/view_python"
# name for the view
view_name="hpc-python-collection"
# target directory for view installation
view_software_root_dir="${INSTALL_PREFIX}/${custom_software_dir}/${cpu_arch}/gcc/${gcc_version}"
view_software_dir="${view_software_root_dir}/${view_name}"
# target directory for view module
view_module_dir="${INSTALL_PREFIX}/${custom_modules_dir}/${cpu_arch}/gcc/${gcc_version}/${custom_modules_suffix}/${view_name}"
# template for view module
view_module_template="${PAWSEY_SPACK_CONFIG_REPO}/scripts/templates/module_hpc_python_collection.lua"

# only proceed if original environment yaml exists
if [ -e ${original_env_yaml} ] ; then


# make sure required directories exist
mkdir -p ${view_env_dir}
mkdir -p ${view_software_root_dir}
mkdir -p ${view_module_dir}

rm -rf ${view_env_dir}/spack.* ${view_env_dir}/.spack*
rm -rf ${view_software_dir} ${view_software_root_dir}/._${view_name}
rm -f ${view_module_dir}/*.lua


# create Spack environment with view
sed "s;  view: .*[fF]alse;  view: ${view_software_dir};g" \
  ${original_env_yaml} \
  >${view_env_dir}/spack.yaml
spack env activate -V ${view_env_dir}
spack concretize -f
# get info for the modulefile
# the grep syntax works as of spack v0.17.0
view_root_packages=$( spack find | sed -n '/Root specs/,/^$/p' | grep -v -e '^==>' -e '^--' -e '^$' | cut -d '%' -f 1 )
spack env deactivate

# create modulefile for view
view_python_version=$( echo $view_root_packages | xargs -n 1 | grep ^python@ | cut -d '@' -f 2 )
view_version="${date_tag}-py${view_python_version}"
view_python_version_major="$( echo $view_python_version | cut -d '.' -f 1 )"
view_python_version_minor="$( echo $view_python_version | cut -d '.' -f 2 )"
view_python_version_major_minor="${view_python_version_major}.${view_python_version_minor}"
sed \
  -e "s;VIEW_VERSION;${view_version};g" \
  -e "s;VIEW_ROOT_PACKAGES;$( echo ${view_root_packages} );g" \
  -e "s;VIEW_ROOT;${view_software_dir};g" \
  -e "s;VIEW_PYTHON_VERSION_MAJOR_MINOR;${view_python_version_major_minor};g" \
  ${view_module_template} \
  >${view_module_dir}/${view_version}.lua


else
  echo "Original environment yaml not found: ${original_env_yaml}"
  echo "Exiting."
  exit 1
fi
