#!/bin/bash

function PackageCheck() 
{
    # missing from zypper 
    # ncdu z3
    # package list
    packages=(\
    libz1 zlib-devel libpopt0 popt-devel \
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
    texinfo \
    vim \
    wget \
    xz xz-devel \
    yasm \
    libz1 zlib-devel \
    libzstd1 libzstd-devel \
    python-devel \
    lz4
    )
    
    runarg="zypper info"
    fname=$1 
    if [ $# -eq 2 ]
    then 
        runarg="$2 ${runarg}"
    fi
    echo "Packages of interest: ${packages[@]} '\n'"
    echo "Saving results to $fname"
    for p in ${packages[@]}
    do
        ${runarg} $p 1> $p.out 2> /dev/null
        name=$(grep "Name" $p.out | awk '{print $3}' )
        installed=$(grep "Installed      : Yes" $p.out)
        message=""
        if [ -z "$installed" ]
        then
            message="Package $p"
            message="${message}: Not installed!"
            echo ${message}
            echo "Running substring search"
            ${runarg} -s ${p}
	
        else 
            version=$(grep "Version" $p.out | sed "s:-: :g" | awk '{print $3}' )
            message="Package ${name}"
            message="${message}@${version}"
        fi 
        rm $p.out 
        echo ${message} >> ${fname}
    done
}


function NodeCheck() 
{
    timestamp=$(date +"%Y-%m-%d_%Hh%M")
    basename="package_results.node"
    echo "Checking system-wide root installs of packges @ ${timestamp}"
    check_login=1
    check_compute=0
    loginnode=$(hostname)
    nodelist=(001008 001009 001010 001011 001020 001021 001022 001023 001028 001029 001030 001031)
    while getopts l:n: flag
    do
        case "${flag}" in
            l) check_login=${OPTARG};;
            n) check_compute=${OPTARG};;
        esac
    done
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

