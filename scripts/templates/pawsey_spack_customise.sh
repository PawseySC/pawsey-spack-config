#!/bin/bash

function print_help() {
    echo """spack [project] customise help:

spack customise <packgage-name>: copy the package from the Pawsey or built-in repository.
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

if [ "${USER_OR_PROJECT_INSTALL}" = "user" ]; then
    DEST_PACKAGE_RECIPE_DIR="${MYSOFTWARE}/${PAWSEY_CLUSTER}/${PAWSEY_STACK_VERSION}/spack_repo/packages/${PACKAGE_NAME}"
elif [ "${USER_OR_PROJECT_INSTALL}" = "project" ]; then
    DEST_PACKAGE_RECIPE_DIR="/software/projects/${PAWSEY_PROJECT}/${PAWSEY_CLUSTER}/${PAWSEY_STACK_VERSION}/spack_repo/packages/${PACKAGE_NAME}"
else
    echo "Unrecognised install mode: ${USER_OR_PROJECT_INSTALL}"
    exit 1
fi

if [ "${PACKAGE_NAME}" = "" ]; then
    echo "Invalid, empty package name."
    exit 1
fi

mkdir -p "${DEST_PACKAGE_RECIPE_DIR}"

if [ "${RECIPE_URL}" = "" ]; then
    # get the recipe from the system-wide Pawsey or builtin repo, in that order
    PACKAGE_DIR_PREFIX="/software/${PAWSEY_CLUSTER}/${PAWSEY_STACK_VERSION}/spack/var/spack/repos"
    PAWSEY_REPO="${PACKAGE_DIR_PREFIX}/pawsey/packages/${PACKAGE_NAME}"
    BUILTIN_REPO="${PACKAGE_DIR_PREFIX}/builtin/packages/${PACKAGE_NAME}"
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

spack edit "${PACKAGE_NAME}"
