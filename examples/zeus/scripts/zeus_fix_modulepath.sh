#!/bin/bash 

echo "Copying modules ... "
oldmodinstallpath=/group/pawsey0001/maali/software/sles12sp3/spack/modulefiles/
newmodinstallpath=/pawsey/sles12sp3/spack/modulefiles/

cp -r ${oldmodinstallpath}/* ${newmodinstallpath}

cd ${newmodinstallpath}/x86_64/Core

echo "Done."

echo "Fixing paths ... "

oldpath=/group/pawsey0001/maali/software/sles12sp3/spack/software/
newpath=/pawsey/sles12sp3/spack/software/
for f in devel/dependencies/.*/* 
do 
	echo "Module $f" 
	sed -i 's:'"${oldpath}"':'"${newpath}"':g' ${f}
done

for f in */*/*/*.lua
do 
	echo "Module $f" 
	sed -i 's:'"${oldpath}"':'"${newpath}"':g' ${f}
done

echo "Done."
