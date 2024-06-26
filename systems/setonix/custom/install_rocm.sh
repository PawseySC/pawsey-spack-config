#!/bin/bash

# Input variables

ROCM_VERSION=6.1.2 # TODO: at the RPM repo there is only the latest version
INSTALL_DIR=${MYSOFTWARE}/installed-rocm
# We are not really building anything, just download prebuilt binaries and
# extracting them. Doing it on /software means moving them to the final location
# is only matter of changing a inode tree, instead of actually copying files.
# Expected number of inodes consumed: 10K
BUILD_DIR=${MYSOFTWARE}/build-rocm-${ROCM_VERSION}

function extract_rpm {
 rpm2cpio ${1} | cpio -idmv
}

base_url=https://repo.radeon.com/rocm/yum/rpm/
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

ESCAPED_ROCM_VERSION=`echo $ROCM_VERSION | sed 's|\.|\\\.|g'`
wget -O - ${base_url} | grep -oe "href.*rpm" | cut -d\" -f2 | grep -ve "-rpath" | grep -e "${ESCAPED_ROCM_VERSION}" |  sed "s|^|wget $base_url|g" > download_script.sh

# Start the download of RPMs in parallel

NPARALLEL=20

declare -i count
declare -i batch
count=0
batch=0
while read cmdline
do
(( count=count+1 ))
if [ $count -eq $NPARALLEL ]; then
    count=0
    (( batch=batch+1 ))
    echo "Waiting for $NPARALLEL downloads to finish in batch $batch"
    wait
fi
$cmdline &
done < download_script.sh

for rpm_file in `ls -1 *.rpm`;
do
extract_rpm "${rpm_file}"
done

mkdir -p ${INSTALL_DIR}
mv ./opt/rocm-${ROCM_VERSION} ${INSTALL_DIR}/
