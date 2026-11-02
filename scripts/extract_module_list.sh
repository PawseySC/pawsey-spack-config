#!/bin/bash

DATE_TAG="2026.09"
GCC_VERSION="14.2.0"
DATE_TAG="2025.06"
GCC_VERSION="14.2.0"
INSTALL_PREFIX="/software/setonix/${DATE_TAG}"

MODULE_ROOT="${INSTALL_PREFIX}/modules/zen3/gcc/${GCC_VERSION}"
OUTPUT="modules_${DATE_TAG}_gcc_${GCC_VERSION}.txt"

find "$MODULE_ROOT" \
    \( -type f -o -type l \) \
    -name '*.lua' \
    ! -path '*/.*' \
    -print |
while read -r file; do
    version=$(basename "$file" .lua)
    package=$(basename "$(dirname "$file")")

    echo "${package}/${version}"
done |
sort -u > "$OUTPUT"

echo "Module list written to: $OUTPUT"
echo "Number of modules: $(wc -l < "$OUTPUT")"
