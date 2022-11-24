#!/bin/bash

function PackageCheck()
{
    # currently has placeholders containing "?" which need to be updated 
    # since packages with ? are typically ones where the number keeps changing, 
    # one can alter search to use these to find possible names 
    packages_with_varying_names=(
    "libedit?" \
    "libelf?" \
    "libffi?" \
    "libfuse?" \
    "libicu-s*" \
    "libjpeg?" "libjpeg?-devel" \
    "libnuma?" \
    "libpciaccess?" \
    "libpng????" "libpng??-devel" \
    "libxml2-?" \
    "libX11-?" \
    "libreadline*" \
    "libyaml????" \
    hwloc hwloc-devel \
    )

    # list of packages 
    packages=(\
    libz1 zlib-devel zlib-devel-static \
    libpopt0 popt-devel \
    shadow \
    libuuid-devel libuuid1 util-linux \
    lvm2 lvm2-devel \
    squashfs \
    cryptsetup libcryptsetup-devel \
    alsa-lib \
    autoconf \
    autogen \
    automake \
    binutils \
    bison \
    bzip2 libbz2-devel \
    curl \
    diffutils \
    emacs \
    ffmpeg \
    flex \
    libfreetype6 freetype2-devel \
    gettext-runtime perl-gettext gettext-tools \
    make \
#    hwloc hwloc-devel \
    cray-hwloc \
    libedit0 libedit-devel \
    libelf1 libelf-devel \
    libffi7 libffi-devel \
    libfuse2 fuse-devel \
    libicu-suse65_1 libicu-devel \
    libjpeg8 libjpeg8-devel \
    libnuma1 libnuma-devel \
    libpciaccess0 libpciaccess-devel \
    libpng12-0 libpng16-16 libpng12-devel libpng16-devel \
    libxml2-2 libxml2-devel \
    libX11-6 libX11-devel \
    libyaml-0-2 libyaml-devel \
    nano \
    nasm \
    ncurses-utils ncurses-devel \
    ninja \
    numactl \
    openssl \
    perl \
    pkg-config
    libreadline7 readline-devel \
    rsync \
    sqlite3 sqlite3-devel \
    subversion \
    swig \
    tar \
    tcl \
    texinfo texlive-ae texlive-fancyvrb \
    vim \
    wget \
    xz xz-devel xz-static-devel \
    yasm \
    python-devel \
    lz4 \
    maven \
    libseccomp2 libseccomp-devel \
    zstd libzstd1 \
    libgpg-error0 libgpg-error-devel \
    icu.691 icu4j \
    libblkid1 libblkid-devel \
    )

    # number of lines return by zypper that contains useful info about a package
    num_lines=12
    runarg="zypper info"
    fname=$1
    if [ $# -eq 2 ]
    then
        runarg="$2 ${runarg}"
    fi
    echo "Packages of interest: ${packages[@]} "
    echo "Saving results to $fname"

    rm -f all_packages.out
    ${runarg} "${packages[@]}" 1> all_packages.out 2> /dev/null

    for p in ${packages[@]}
    do
	# get rid of any ? in the package name for now, need to update list
    p=$(echo $p | sed "s:?::g" | sed "s:*::g")
    viable=$(grep -c "Information for package $p:" all_packages.out)
	if [ "${viable}" -gt "0" ]; then
        # get the info associated with the pacakge form information of all packages
        end=$(grep -n "Information for package $p:" all_packages.out | sed "s\:\ \g" | awk -v var=${num_lines} '{print $1+var}')
		head -n ${end} all_packages.out | tail -n ${num_lines} > $p.out
        installed=$(grep "Installed      : Yes" $p.out)
        message=""
        if [ -z "$installed" ]
        then
            message="Package $p"
            message="${message}: Not installed!"
            echo ${message}
        else
            version=$(grep "Version" $p.out | sed "s:-: :g" | awk '{print $3}' )
            message="Package ${p}"
            message="${message}@${version}"
        fi
        rm $p.out
    else
        listofpossiblenames=$(${runarg} -s ${p} | grep "Information for package " | sed "s\:\ \g" | sed "s:Information for package::g")
        message="Package $p"
        message="${message}: Not in list of packages, possible names ${listofpossiblenames}"
        echo ${message}
    fi
    echo ${message} >> ${fname}
    done
    rm -f all_packages.out
}

function NodeCheck()
{
    local timestamp=$(date +"%Y-%m-%d_%Hh%M")
    local basename="package_results.node"
    echo "Checking system-wide root installs of packges @ ${timestamp}"
    local check_login=1
    local check_compute=0
    local loginnode=$(hostname)
    while getopts l:n: flag
    do
        case "${flag}" in
            l) check_login=${OPTARG};;
            n) check_compute=${OPTARG};;
        esac
    done
    # if checking compute get list of all nodes
    local nodelist=()
    local partitionlist=()
    if [ ${check_compute} -eq '1' ]
    then
        nodelist=($(scontrol show nodes | grep NodeName| sed "s:NodeName=::g" | awk '{print $1}'))
        partitionlist=($(scontrol show nodes | grep Partitions | sed "s:Partitions=::g" | awk '{print $1}'))
    fi
    # output listof nodes to be checked 
    local message="Checking: "
    if [ ${check_login} -eq '1' ]
    then
        message="${message} Login "
    fi
    states=("DOWN" "NOT_RESPONDING" "IDLE+RESERVED")
    if [ ${check_compute} -eq '1' ]
    then
        local activenodes=""
        for nid in ${nodelist[@]}
        do
	        local state=$(scontrol show node ${nid} | grep State= | sed "s:State=::g" | awk '{print $1}')
            if [ "${state}" = "IDLE" ]
            then
                activenodes="${activenodes} ${nid}"
            fi
        done
        message="${message} ${activenodes} "
    fi
    echo $message

    if [ ${check_login} -eq '1' ]
    then
        PackageCheck ${basename}.${loginnode}.${timestamp}.out
    fi
    if [ ${check_compute} -eq '1' ]
    then
        for ((i=0;i<${#nodelist[@]};i++))
        do
        	local nid=${nodelist[${i}]}
        	local p=${partitionlist[${i}]}
            local state=$(scontrol show node ${nid} | grep State= | sed "s:State=::g" | awk '{print $1}')
            if [ "${state}" = "IDLE" ]
            then
                PackageCheck ${basename}.${nid}.${timestamp}.out "srun -w ${nid} -p ${p} -n 1 -c 1"
            fi
        done
    fi
}
