#!/bin/bash

# Pawsey compilation environment
STACK_VERSION=2025.08
COMPILER=gcc
COMPILER_VERSION=14.2.0
OSARCH=linux-sles15-zen3
ARCH=zen3

PROGRAM_NAME=pshell
PROGRAM_VERSION=1.2.0

#For system installation:
INSTALL_DIR_PREFIX=/software/setonix/$STACK_VERSION/software/$OSARCH/$COMPILER-$COMPILER_VERSION/$PROGRAM_NAME-$PROGRAM_VERSION
MODULEFILE_DIR=/software/setonix/$STACK_VERSION/modules/$ARCH/$COMPILER/$COMPILER_VERSION/utilities/$PROGRAM_NAME

#For local installation:
#INSTALL_DIR_PREFIX=$MYSOFTWARE/setonix/$STACK_VERSION/software/$OSARCH/$COMPILER-$COMPILER_VERSION/$PROGRAM_NAME-$PROGRAM_VERSION
#MODULEFILE_DIR=$MYSOFTWARE/setonix/$STACK_VERSION/modules/$ARCH/$COMPILER/$COMPILER_VERSION/$PROGRAM_NAME

mkdir -p $INSTALL_DIR_PREFIX/bin
mkdir -p $MODULEFILE_DIR

cd $MYSCRATCH/setonix/2025.08
wget https://github.com/PawseySC/pshell/archive/refs/tags/v1.2.0.tar.gz
tar -xvf v1.2.0.tar.gz
cd pshell-1.2.0
./build_release
cp release/pshell $INSTALL_DIR_PREFIX/bin

# Create module file

echo "-- Modulefile for $PROGRAM_NAME.
local root_dir = '$INSTALL_DIR_PREFIX'
if (mode() ~= 'whatis') then
    prepend_path('PATH', root_dir .. '/bin')
    setenv('PAWSEY_PSHELL_HOME', '$INSTALL_DIR_PREFIX')
end
    " > "$MODULEFILE_DIR/${PROGRAM_VERSION}.lua"


