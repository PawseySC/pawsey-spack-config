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

