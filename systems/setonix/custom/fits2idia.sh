#!/bin/bash

# Pawsey compilation environment
STACK_VERSION=2024.05
COMPILER=gcc
COMPILER_VERSION=12.2.0
OSARCH=linux-sles15-zen3
ARCH=zen3

PROGRAM_NAME=fits2idia
PROGRAM_VERSION=0.1.15 

INSTALL_DIR_PREFIX=/software/setonix/$STACK_VERSION/software/$OSARCH/$COMPILER-$COMPILER_VERSION/$PROGRAM_NAME-$PROGRAM_VERSION
MODULEFILE_DIR=/software/setonix/$STACK_VERSION/modules/$ARCH/$COMPILER/$COMPILER_VERSION/libraries/$PROGRAM_NAME

mkdir -p $INSTALL_DIR_PREFIX
mkdir -p $MODULEFILE_DIR

cd $MYSCRATCH/setonix/2024.05
wget https://github.com/CARTAvis/fits2idia/archive/refs/tags/v0.1.15.tar.gz
tar -xvf v0.1.15.tar.gz 
cd fits2idia-0.1.15/
mkdir -p build
cd build
module load cfitsio/4.3.0 .hdf5/1.14.3-q2qmfcl #need HDF5 installation with C++ binding support
cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR_PREFIX/ ..
make
make install

# Create module file

echo "-- Modulefile for $PROGRAM_NAME.
local root_dir = '$INSTALL_DIR_PREFIX'
load(\"cfitsio/4.3.0\")
load(\".hdf5/1.14.3-q2qmfcl\")
if (mode() ~= 'whatis') then
    prepend_path('PATH', root_dir .. '/bin')
    setenv('FITS2IDIA_HOME', '$INSTALL_DIR_PREFIX')
end
    " > "$MODULEFILE_DIR/${PROGRAM_VERSION}.lua"


