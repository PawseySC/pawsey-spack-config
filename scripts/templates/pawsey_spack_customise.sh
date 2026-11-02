#!/bin/bash -e

function print_help() {
    echo """spack [project] customise help:

spack customise <package-name>: copy the package from the Pawsey or built-in repository.
spack customise <package-name> URL: download the package.py file from the given URL.
spack customise <package-name> path: copy the package.py file from the given filesystem path.
"""

}


if (( $# < 2 )); then
    echo "Error: spack customise requires at least one argument, the package name."
    print_help
    exit 1
fi

USER_OR_PROJECT_INSTALL="${1}"
PACKAGE_NAME="${2}"
RECIPE_URL="${3}"

stack_system="${PAWSEY_STACK_SYSTEM:-${PAWSEY_CLUSTER}}"
project_files_prefix="${PAWSEY_PROJECT_FILES_PREFIX:-/software/projects}"
spack_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
if [ -z "${PAWSEY_PROJECT}" ]; then
    echo "PAWSEY_PROJECT is not set. Load the pawsey module or select a project first." >&2
    exit 1
fi
if [ "${USER_OR_PROJECT_INSTALL}" = "user" ]; then
    recipe_repo="${project_files_prefix}/${PAWSEY_PROJECT}/${USER}/${stack_system}/${PAWSEY_STACK_VERSION}/spack_repo"
elif [ "${USER_OR_PROJECT_INSTALL}" = "project" ]; then
    recipe_repo="${project_files_prefix}/${PAWSEY_PROJECT}/${stack_system}/${PAWSEY_STACK_VERSION}/spack_repo"
else
    echo "Unrecognised install mode: ${USER_OR_PROJECT_INSTALL}"
    exit 1
fi
DEST_PACKAGE_RECIPE_DIR="${recipe_repo}/packages/${PACKAGE_NAME}"

if [ "${PACKAGE_NAME}" = "" ]; then
    echo "Invalid, empty package name."
    exit 1
fi

mkdir -p "${DEST_PACKAGE_RECIPE_DIR}"
if [ ! -f "${recipe_repo}/repo.yaml" ]; then
    printf 'repo:\n  namespace: %s_repo\n' "${USER_OR_PROJECT_INSTALL}" > "${recipe_repo}/repo.yaml"
fi

if [ "${RECIPE_URL}" = "" ]; then
    # get the recipe from the system-wide Pawsey or builtin repo, in that order
    PACKAGE_DIR_PREFIX="${spack_dir}/var/spack/repos"
    PAWSEY_REPO="${PACKAGE_DIR_PREFIX}/pawsey/packages/${PACKAGE_NAME}"
    BUILTIN_REPO="${PACKAGE_DIR_PREFIX}/builtin/repos/spack_repo/builtin/packages/${PACKAGE_NAME}"
    if [ ! -d "${BUILTIN_REPO}" ]; then
        BUILTIN_REPO="${PACKAGE_DIR_PREFIX}/builtin/packages/${PACKAGE_NAME}"
    fi
    if [ -d "${PAWSEY_REPO}" ]; then
        echo "Retrieving the recipe from the Pawsey repository.."
        cp -r "${PAWSEY_REPO}/"* "${DEST_PACKAGE_RECIPE_DIR}/"
    elif [ -d "${BUILTIN_REPO}" ]; then
        echo "Retrieving the recipe from the builtin repository.."
        cp -r "${BUILTIN_REPO}/"* "${DEST_PACKAGE_RECIPE_DIR}/"
    else
        echo "Package recipe not found on the system. Please raise a ticket with the helpdesk."
        exit 1
    fi
else
    # The URL or path to the package.py file is provided
    if [[ "${RECIPE_URL}" == "http"* ]]; then 
        echo "Downloading the recipe from the provided URL.."
        wget "${RECIPE_URL}" -O "${DEST_PACKAGE_RECIPE_DIR}/package.py"
    else
        echo "Copying the recipe from the provided path.."
        cp "${RECIPE_URL}" "${DEST_PACKAGE_RECIPE_DIR}/package.py"
    fi
fi

if [ "${USER_OR_PROJECT_INSTALL}" = "project" ]; then
    "${spack_dir}/bin/spack" project edit "${PACKAGE_NAME}"
else
    "${spack_dir}/bin/spack" edit "${PACKAGE_NAME}"
fi
