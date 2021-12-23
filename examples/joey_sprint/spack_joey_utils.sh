#!/bin/bash

joey_spack_repodir=$( dirname $(pwd)/${BASH_SOURCE} )

function joey_spack_start() {
	module load cray-python
	if [ -f ${HOME}/.spack/joeyspackset.txt ]
	then 
		SPACKROOT=$(head -n 1 ${HOME}/.spack/joeyspackset.txt)
		JOEYSPACKDATE=$(head -n 2 ${HOME}/.spack/joeyspackset.txt | tail -n 1)
		echo "Spack already setup at ${JOEYSPACKDATE}, resourcing paths"
		source ${SPACKROOT}/share/spack/setup-env.sh
		spack debug report
		return 1 
	fi

	SPACKROOT=${HOME}/spack-repo
	if [ ! -z $1 ] 
	then
		SPACKROOT=$1
	fi 
	SPACKVER=v0.17.0
        if [ ! -z $2 ]
	then
		SPACKVER=$2
	fi 
	echo "Starting Spack on Joey located at ${SPACKROOT}"
	if [ ! -d ${SPACKROOT} ] 
	then
		echo "Cloning spack as directory not present" 
		git clone https://github.com/PawseySC/spack ${SPACKROOT}
	fi

	# checkout appropriate branch
	curdir=$(pwd)
	cd ${SPACKROOT}; git checkout ${SPACKVER}; cd ${curdir}

	# copy configs if necessary
	cp ${joey_spack_repodir}/configs/*.yaml ${SPACKROOT}/etc/spack/
	sed -i 's|REPOPATH|'"${joey_spack_repodir}"'|g' ${SPACKROOT}/etc/spack/repos.yaml
	sed -i 's|REPOPATH|'"${joey_spack_repodir}"'|g' ${SPACKROOT}/etc/spack/config.yaml
	# Use provided json to avoid crash on compute nodes
	cp ${joey_spack_repodir}/fixes/microarchitectures.json ${SPACKROOT}/lib/spack/external/archspec/json/cpu/
	# do a clean of the older spack
	cur=$(date -Iminutes)
	mv ~/.spack ~/.spack_${cur}
	mkdir -p ${HOME}/.spack
	source ${SPACKROOT}/share/spack/setup-env.sh
	echo "Now in spack. Spack has "
	echo $(which spack)
	spack debug report
	spack compilers
	echo "Get clingo by specing zlib"
	spack spec zlib # >> /dev/null 
	echo "External packages are "
	spack external list
	echo "Currently loaded modules"
	module list
	echo "-------------------------"

	echo $SPACKROOT > ${HOME}/.spack/joeyspackset.txt
	date -Iminutes >> ${HOME}/.spack/joeyspackset.txt
	spack debug report >> ${HOME}/.spack/joeyspackset.txt
	spack compilers >> ${HOME}/.spack/joeyspackset.txt
	spack external list >> ${HOME}/.spack/joeyspackset.txt
}

function joey_spack_keep_record()
{
	if [ -f ${HOME}/.spack/joeyspackset.txt ]
	then
		echo "Keeping record of current spack setup and installed packages"
		SPACKROOT=$(head -n 1 ${HOME}/.spack/joeyspackset.txt)
		JOEYSPACKDATE=$(head -n 2 ${HOME}/.spack/joeyspackset.txt | tail -n 1)
		echo "Recording current spack, which was setup at ${JOEYSPACKDATE}"
		cur=$(date -Iminutes)
		record=${HOME}/.spack/joey_record_${cur}.txt
		record_dir=${HOME}/.spack/joey_record_${cur}_configs/
		echo $SPACKROOT > ${record}
		date -Iminutes >> ${record}
		spack debug report >> ${record}
		echo "Compilers" >> ${record}
		echo "-------------------------" >>${record}
		spack compilers >> ${record}
		echo "Externals">> ${record}
		echo "-------------------------" >> ${record}
		spack external list >> ${record}
		echo "Installed" >> ${record}
		echo "-------------------------"
		spack find -ldv >> ${record}
		mkdir -p ${record_dir}
		cp ${SPACKROOT}/etc/spack/*yaml ${record_dir}
		echo "Finished, see ${record} and ${record_dir}"
	else 
		echo "Not recording as there is no joeyspackset file"
	fi
	
}

function joey_spack_debug_spec()
{
	echo "Debug spec using original concretiser"
	if [ ! -z $2 ] 
	then
		echo "Provide speck within quotes as a single argument, \"<spec>\" "
		return 0
	fi
	spec=$1
	echo "Spec of $spec"
	cur=$(date -Iminutes)
	echo $spec > spec_$cur.txt
	echo "Clingo " >> spec_$cur.txt
	spack spec $spec >> spec_$cur.txt
	# update config file to use original
	echo "Original " >> spec_$cur.txt
	sed -i 's|concretizer: clingo|#concretizer: clingo|'g ${SPACKROOT}/etc/spack/config.yaml
	sed -i 's|#concretizer: original|concretizer: original|'g ${SPACKROOT}/etc/spack/config.yaml
	spack spec $spec >> spec_$cur.txt
	# revert back to clingo
	sed -i 's|#concretizer: clingo|concretizer: clingo|'g ${SPACKROOT}/etc/spack/config.yaml
	sed -i 's|concretizer: original|#concretizer: original|'g ${SPACKROOT}/etc/spack/config.yaml

	echo "See spec_$cur.txt for concretization with clingo and original"
}

function PackageCheck() 
{
    # missing from zypper 
    # ncdu z3
    # package list
    packages=(\
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
    "libfreetype?" freetype2-devel \
    gettext-runtime \
    perl-gettext \
    gettext-tools \
    make \
    hwloc hwloc-devel \
    "libedit?" libedit-devel \
    "libelf?" libelf-devel \
    "libffi?" libffi-devel \
    "libfuse?" fuse-devel \
    "libicu????" libicu-devel \
    "libjpeg?" "libjpeg?-devel" \
    "libnuma?" libnuma-devel \
    "libpciaccess?" libpciaccess-devel \
    "libpng16???" "libpng16-devel" \
    "libpng12??" "libpng12-devel" \
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
    squashfs \
    subversion \
    swig \
    tar \
    tcl \
    texinfo \
    vim \
    wget \
    xz xz-devel \
    yasm \
    "libz?" zlib-devel \
    "libzstd?" libzstd-devel \
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
    timestamp=$(date -Iminutes)
    basename="package_results.node"
    echo "Checking system-wide root installs of packges @ ${timestamp}"
    check_login=1
    check_compute=0
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
        PackageCheck ${basename}.ln01.${timestamp}.out 
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

function ParallelSpackInstall() 
{
	echo "Running an install of an activated environment in spack"
    if [ $# -ne 2 ]
    then 
		echo "Provide number of cores to run per spack installation and number of these to run in parallel, separated by sleep 10. "
		echo "ParallelSpackInstall 4 4 # runs 4 \"spack install -j4 \" "
        return 
    fi
	for ((i=0;i<$2;i++))
	do 
		spack install -j$1 1> spack.${i}.out 2> spack.${i}.err &
		sleep 10 
	done
}
