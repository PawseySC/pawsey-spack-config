#!/bin/bash

if [ -z $1 ]; then
	echo "Must provide the compiler@version of builds that need to be updated"
	echo "E.g., if all gcc@10.2.0 are outdated, arg is gcc@10.2.0"
	exit
fi
# get the compiler
compiler=$1
rebuild='n'
if [ ! -z $2 ]; then
	rebuild=$2
fi

echo "Will uninstall all packages found with compiler ${compiler}"
if [ $rebuild = "y" ]; then
	echo "And reinstall"
fi

# load the spack module
spackmod=$(module avail spack 2>&1 >/dev/null | grep spack | awk '{print $1}')
echo "Loading ${spackmod}"
module load ${spackmod}

#now find all packages installed with older compiler passed as argument 
packages=($(spack find -vp %${compiler} | tac | awk '{print $1}'))
hashes=($(spack find -Lvp %${compiler} | tac | awk '{print $1}'))
numpackages=$((${#packages[@]}-1))
for ((i=0;i<${numpackages};i++))
do
	p=${packages[${i}]}
	h=${hashes[${i}]}
	echo "Currently /${h}    ${p} :"
	spack find -lvdp /${h}
	echo "Uninstalling ... "
	spack uninstall --all --dependents -y /${h}
	if [ $rebuild = "y" ]; then
		echo "and installing ... "
		echo "New spec :"
		spack spec -Il ${p}
		spack install ${p}
	fi
done

