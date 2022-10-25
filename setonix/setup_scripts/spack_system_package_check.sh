#!/bin/bash

function PackageCheck()
{
    # missing from zypper
    # ncdu z3
    # package list
    # currently has placeholders containing "?" which need to be updated 
    # based on list of 
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
    "libfreetype?" freetype-devel \
    gettext-runtime perl-gettext gettext-tools \
    make \
    hwloc hwloc-devel \
    "libedit?" libedit-devel \
    "libelf?" libelf-devel \
    "libffi?" libffi-devel \
    "libfuse?" fuse-devel \
    "libicu-s*" libicu-devel \
    "libjpeg?" "libjpeg?-devel" \
    "libnuma?" libnuma-devel \
    "libpciaccess?" libpciaccess-devel \
    "libpng????" "libpng??-devel" \
    "libxml2-?" "libxml2-devel" \
    "libX11-?" "libX11-devel" \
    "libyaml????" "libyaml-devel" \
    nano \
    nasm \
    "ncurses-utils" "ncurses-devel" \
    ninja \
    numactl \
    openssl \
    perl \
    "pkg-config"
    "libreadline*" "readline-devel" \
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
    timestamp=$(date +"%Y-%m-%d_%Hh%M")
    basename="package_results.node"
    echo "Checking system-wide root installs of packges @ ${timestamp}"
    check_login=1
    check_compute=0
    loginnode=$(hostname)
    while getopts l:n: flag
    do
        case "${flag}" in
            l) check_login=${OPTARG};;
            n) check_compute=${OPTARG};;
        esac
    done
    # if checking compute get list of all nodes
    if [ ${check_compute} -eq '1' ]
    then
        nodelist=($(scontrol -o show nodes | sed "s:NodeName=::g" | sed "s:nid::g" | awk '{print $1}'))
    fi
    # output listof nodes to be checked 
    message="Checking: "
    if [ ${check_login} -eq '1' ]
    then
        message="${message} Login "
    fi
    if [ ${check_compute} -eq '1' ]
    then
        activenodes=""
        for n in ${nodelist[@]}
        do
            active=$(sinfo -n nid${n} | grep "down")
            if [ -z "${active}" ]
            then
                activenodes="${activenodes} ${n}"
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
        for n in ${nodelist[@]}
        do
            active=$(sinfo -n nid${n} | grep "down")
            if [ -z "${active}" ]
            then
                PackageCheck ${basename}.nid${n}.${timestamp}.out "srun -w nid${n} -n 1 -c 1"
            fi
        done
    fi
}
