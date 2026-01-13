#!/bin/bash -e
#
# Deploy custom utility modules from system-specific templates
# Reads utility_module_list from settings.sh
#

if [[ -z "${INSTALL_PREFIX}" || -z "${SYSTEM}" ]]; then
    echo "Error: settings.sh must be sourced first"
    exit 1
fi

PAWSEY_SPACK_CONFIG_REPO="${PAWSEY_SPACK_CONFIG_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "${utility_module_list}" ]]; then
    echo "No utility modules to deploy (utility_module_list is empty)"
    exit 0
fi

gcc_compat_ver="${gcc_compat_version//./_}"

echo "Deploying custom utility modules for ${SYSTEM}..."
echo ""

for module_name in ${utility_module_list}; do
    TEMPLATE="${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/templates/modules/${module_name}.lua"
    MODULE_DIR="${INSTALL_PREFIX}/${utilities_modules_dir}/${module_name}"
    MODULE_VERSION="${DATE_TAG}"
    
    echo "  Module: ${module_name}"
    echo "    Template: ${TEMPLATE}"
    echo "    Output: ${MODULE_DIR}/${MODULE_VERSION}.lua"
    
    if [[ ! -f "${TEMPLATE}" ]]; then
        echo "    WARNING: Template not found, skipping"
        echo ""
        continue
    fi

    mkdir -p "${MODULE_DIR}"

    sed \
        -e "s;VERSION;${MODULE_VERSION};g" \
        -e "s;BUILD_DATE;$(date +%Y-%m-%d);g" \
        -e "s;GCC_VERSION;${gcc_version};g" \
        -e "s;GCC_COMPAT_VERSION;${gcc_compat_ver};g" \
        -e "s;NVIDIA_VERSION;${nvidia_version};g" \
        -e "s;INSTALL_PREFIX;${INSTALL_PREFIX};g" \
        -e "s;SYSTEM;${SYSTEM};g" \
        "${TEMPLATE}" \
        > "${MODULE_DIR}/${MODULE_VERSION}.lua"
    
    echo "    Done"
    echo ""
done

echo "Utility module deployment complete"
