#!/bin/bash 

export PATH=$PATH:/group/pawsey0001/maali/software/sles12sp3/spack/software/linux-sles12-x86_64/gcc-4.8.5/patchelf-0.13-7bnpxeuq5t63osdftl3rnlkvqgxembdb/bin/
oldinstallpath=/group/pawsey0001/maali/software/sles12sp3/spack/software/
newinstallpath=/pawsey/sles12sp3/spack/software/

copy="y"
fix="y"
if [ ! -z $1 ]; then
	copy=$1
fi 
if [ ! -z $2 ]; then
	fix=$2
fi 

if [ "${copy}" = "y" ]; then 
	echo "Copying installation ... "
	echo "cp -r ${oldinstallpath}/* ${newinstallpath}/"
	cp -r ${oldinstallpath}/* ${newinstallpath}
	echo "Done."
fi


if [ "${fix}" != "y" ]; then
        echo "Not fixing!"
	exit
fi

echo "Fixing paths ... "

cd ${newinstallpath}/linux-sles12-x86_64/gcc-4.8.5/
ipath=$(pwd)
oldpath=/group/pawsey0001/maali/software/sles12sp3/spack/software/
newpath=/pawsey/sles12sp3/spack/software/

for d in ${ipath}/*
do 
	echo "executables in $d" 
	if [ -d ${d}/bin/ ]; then 
		isempty=$(find ${d}/bin/ -maxdepth 0 -empty -exec echo y \;)
		if [ -z ${isempty} ]; then
			for f in ${d}/bin/*
			do
				echo "Fixing ${f}"
				hasrpath=$(readelf -d ${f} | grep "Library rpath" | sed 's: :_:g' | wc -c )
				if [ ${hasrpath} -gt 0 ]; then			
					hasrpath=$(readelf -d ${f} | grep "Library rpath")
					oldstring=$(echo ${hasrpath} | sed 's:\[: :g' | sed 's:\]: :g' | awk '{$1="";$2="";$3=""; $4=""; print}' )
					newstring=$(echo ${oldstring} | sed 's:'"${oldpath}"':'"${newpath}"':g')
					echo "old ${oldstring} new $newstring"
					patchelf --set-rpath ${newstring} ${f}
				fi
			done

		fi
	fi
	if [ -d ${d}/lib/ ]; then 
		isempty=$(find ${d}/lib/ -maxdepth 0 -empty -exec echo y \;)
		if [ -z ${isempty} ]; then
			for f in ${d}/lib/*
			do
				echo "Fixing ${f}"
				hasrpath=$(readelf -d ${f} | grep "Library rpath" | sed 's: :_:g' | wc -c )
				if [ ${hasrpath} -gt 0 ]; then			
					hasrpath=$(readelf -d ${f} | grep "Library rpath")
					oldstring=$(echo ${hasrpath} | sed 's:\[: :g' | sed 's:\]: :g' | awk '{$1="";$2="";$3=""; $4=""; print}' )
					newstring=$(echo ${oldstring} | sed 's:'"${oldpath}"':'"${newpath}"':g')
					echo "old ${oldstring} new $newstring"
					patchelf --set-rpath ${newstring} ${f}
				fi
			done
		fi
	fi 
	if [ -d ${d}/lib64/ ]; then 
		isempty=$(find ${d}/lib64/ -maxdepth 0 -empty -exec echo y \;)
		if [ -z ${isempty} ]; then
			for f in ${d}/lib64/*
			do
				echo "Fixing ${f}"
				hasrpath=$(readelf -d ${f} | grep "Library rpath" | sed 's: :_:g' | wc -c )
				if [ ${hasrpath} -gt 0 ]; then			
					hasrpath=$(readelf -d ${f} | grep "Library rpath")
					oldstring=$(echo ${hasrpath} | sed 's:\[: :g' | sed 's:\]: :g' | awk '{$1="";$2="";$3=""; $4=""; print}' )
					newstring=$(echo ${oldstring} | sed 's:'"${oldpath}"':'"${newpath}"':g')
					echo "old ${oldstring} new $newstring"
					patchelf --set-rpath ${newstring} ${f}
				fi
			done
		fi
	fi
done
