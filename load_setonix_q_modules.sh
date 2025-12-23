source setup_script.sh

cpu_arch="neoverse_v2"

gcc_version="12.3.0"
nvidia_version="24.11"

utilities_root_dir="pawsey"
containers_root_dir="containers"
custom_root_dir="custom"
shpc_containers_modules_dir="${containers_root_dir}/views/modules"
custom_modules_suffix="custom"

# Remove paths to x86 modules
MODULEPATH=$(echo "$MODULEPATH" | tr ':' '\n' | grep -v "/software/setonix/2025.08" | tr '\n' ':' | sed 's/:$//')

echo "${INSTALL_PREFIX/$DATE_TAG}/modules/${cpu_arch}/nvhpc/${nvidia_version}/${category}"
export LMOD_PACKAGE_PATH="/software/setonix-q/lmod-extras:${LMOD_PACKAGE_PATH}"

module use "${INSTALL_PREFIX/$DATE_TAG}/staff_modulefiles"
module use "${INSTALL_PREFIX/$DATE_TAG}/${utilities_root_dir}/modules"
module use "${INSTALL_PREFIX/$DATE_TAG}/${shpc_containers_modules_dir}"

for category in programming-languages utilities libraries applications; do
    module use "${INSTALL_PREFIX/$DATE_TAG}/modules/${cpu_arch}/gcc/${gcc_version}/${category}"
done

for category in programming-languages utilities libraries applications; do
    module use "${INSTALL_PREFIX/$DATE_TAG}/modules/${cpu_arch}/nvhpc/${nvidia_version}/${category}"
done

module use "${INSTALL_PREFIX/$DATE_TAG}/${custom_root_dir}/${cpu_arch}/gcc/${gcc_version}/${custom_modules_suffix}"
module use "${INSTALL_PREFIX/$DATE_TAG}/${custom_root_dir}/${cpu_arch}/nvhpc/${nvidia_version}/${custom_modules_suffix}"

