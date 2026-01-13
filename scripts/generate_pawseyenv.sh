#!/bin/bash -e
#
# Generate a complete pawseyenv.lua module file from the template
# Requires settings.sh to be sourced first.
#
# Usage: source systems/<system>/settings.sh && ./scripts/generate_pawseyenv.sh <output_file>
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/templates/pawseyenv.lua"
OUTPUT_FILE="$1"

# Verify settings are sourced
if [[ -z "${INSTALL_PREFIX}" || -z "${SYSTEM}" ]]; then
    echo "Error: settings.sh must be sourced first"
    echo "Usage: source systems/<system>/settings.sh && ./scripts/generate_pawseyenv.sh <output_file>"
    exit 1
fi

# Verify output file is provided
if [[ -z "${OUTPUT_FILE}" ]]; then
    echo "Error: output_file is required"
    echo "Usage: source systems/<system>/settings.sh && ./scripts/generate_pawseyenv.sh <output_file>"
    exit 1
fi

if [ ! -f "${TEMPLATE_FILE}" ]; then
    echo "Error: Template file not found: ${TEMPLATE_FILE}"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "${OUTPUT_FILE}")"

# Build the module category list in Lua format
module_lua_cat_list=""
for mod_cat in $module_cat_list ; do
    module_lua_cat_list+="\"$mod_cat\", "
done

# Provide defaults for compilers that may not be defined (e.g., setonix-q doesn't use CCE/AOCC)
cce_version="${cce_version:-}"
aocc_version="${aocc_version:-}"
nvidia_version="${nvidia_version:-}"

echo "Generating pawseyenv module for system: ${SYSTEM}"
echo "  DATE_TAG: ${DATE_TAG}"
echo "  INSTALL_PREFIX: ${INSTALL_PREFIX}"
echo "  gcc_version: ${gcc_version}"
echo "  cce_version: ${cce_version:-<not set>}"
echo "  aocc_version: ${aocc_version:-<not set>}"
echo "  nvidia_version: ${nvidia_version:-<not set>}"
echo "  Output: ${OUTPUT_FILE}"
echo ""

# Generate LMOD variable version strings (e.g., 12.3.0 -> 12_3)
gcc_lmod_ver="${gcc_version%.*}"       # 12.3.0 -> 12.3
gcc_lmod_ver="${gcc_lmod_ver//./_}"    # 12.3 -> 12_3
cce_lmod_ver="${cce_version%.*}"
cce_lmod_ver="${cce_lmod_ver//./_}"
aocc_lmod_ver="${aocc_version%.*}"
aocc_lmod_ver="${aocc_lmod_ver//./_}"
nvidia_lmod_ver="${nvidia_version//./_}"  # nvidia is already major.minor

sed \
    -e "s|BASE_INSTALL_PREFIX|${INSTALL_PREFIX}|g" \
    -e "s|CLUSTER|${SYSTEM}|g" \
    -e "s|DATE_TAG|${DATE_TAG}|g" \
    -e "s|USER_PERMANENT_FILES_PREFIX|${USER_PERMANENT_FILES_PREFIX}|g" \
    -e "s;CUSTOM_MODULES_DIR;${custom_modules_dir};g" \
    -e "s;UTILITIES_MODULES_DIR;${utilities_modules_dir};g" \
    -e "s;SHPC_CONTAINERS_MODULES_DIR;${shpc_containers_modules_dir};g" \
    -e "s;CUSTOM_MODULES_SUFFIX;${custom_modules_suffix};g" \
    -e "s;PROJECT_MODULES_SUFFIX;${project_modules_suffix};g" \
    -e "s;USER_MODULES_SUFFIX;${user_modules_suffix};g" \
    -e "s;GCC_VERSION;${gcc_version};g" \
    -e "s;CCE_VERSION;${cce_version};g" \
    -e "s;AOCC_VERSION;${aocc_version};g" \
    -e "s;NVIDIA_VERSION;${nvidia_version};g" \
    -e "s;GCC_LMOD_VERSION;${gcc_lmod_ver};g" \
    -e "s;CCE_LMOD_VERSION;${cce_lmod_ver};g" \
    -e "s;AOCC_LMOD_VERSION;${aocc_lmod_ver};g" \
    -e "s;NVIDIA_LMOD_VERSION;${nvidia_lmod_ver};g" \
    -e "s;MODULE_LUA_CAT_LIST;${module_lua_cat_list};g" \
    "${TEMPLATE_FILE}" \
    > "${OUTPUT_FILE}"

echo "Generated: ${OUTPUT_FILE}"
