#!/bin/bash

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
	repodir=$(git rev-parse --show-toplevel)
	scriptpath=${repodir}/examples/joey_sprint
	cp ${scriptpath}/configs/*.yaml ${SPACKROOT}/etc/spack/
	sed -i 's|REPOPATH|'"${repodir}"'|g' ${SPACKROOT}/etc/spack/repos.yaml
	# Use provided json to avoid crash on compute nodes
	cp ${scriptpath}/fixes/microarchitectures.json ${SPACKROOT}/lib/spack/external/archspec/json/cpu/
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
	#echo "Building cmake if necessary "
	#spack install cmake % gcc
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
		SPACKROOT=$(head -n 1 ${HOME}/.spack/joeyspackset.txt)
		JOEYSPACKDATE=$(head -n 2 ${HOME}/.spack/joeyspackset.txt | tail -n 1)
		echo "Cleaning up spack setup at ${JOEYSPACKDATE}, resourcing paths"
		cur=$(date -Iminutes)
		echo $SPACKROOT > ${HOME}/.spack/joeyspack_unset.txt
		date -Iminutes >> ${HOME}/.spack/joeyspack_unset.txt
		spack debug report >> ${HOME}/.spack/joeyspack_unset.txt
		echo "Compilers"
		spack compilers >> ${HOME}/.spack/joeyspack_unset.txt
		echo "Externals"
		spack external find -lvd >> ${HOME}/.spack/joeyspack_unset.txt
		echo "Installed"
		spack find -ldv >> ${HOME}/.spack/joeyspack_unset.txt
		mkdir -p ~/.spack/joey_sprint/
		cp ${SPACKROOT}/etc/spack/*yaml ~/.spack/joey_sprint/ 
		cp -r ~/.spack ~/.spack_unset_${cur}
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

