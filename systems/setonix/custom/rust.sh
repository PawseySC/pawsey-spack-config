#!/bin/bash

# Pawsey compilation environment
STACK_VERSION=2024.05
COMPILER=gcc
COMPILER_VERSION=12.2.0
OSARCH=linux-sles15-zen3
ARCH=zen3

PROGRAM_NAME=rust
PROGRAM_VERSION=1.78.0 # look up online which version corresponds to stable

INSTALL_DIR_PREFIX=/software/setonix/$STACK_VERSION/software/$OSARCH/$COMPILER-$COMPILER_VERSION/$PROGRAM_NAME-$PROGRAM_VERSION
INSTALL_DIR=$INSTALL_DIR_PREFIX/toolchains/stable-x86_64-unknown-linux-gnu
MODULEFILE_DIR=/software/setonix/$STACK_VERSION/modules/$ARCH/$COMPILER/$COMPILER_VERSION/programming-languages/$PROGRAM_NAME

mkdir -p $INSTALL_DIR_PREFIX
mkdir -p $MODULEFILE_DIR

export CARGO_HOME=$MYSCRATCH/.cargo
export RUSTUP_HOME=$INSTALL_DIR_PREFIX
export RUST_VER=stable

[ -x "$(command -v rustup)" ] \
  || curl https://sh.rustup.rs -sSf | env CARGO_HOME=$CARGO_HOME RUSTUP_HOME=$RUSTUP_HOME sh \
      -s -- -y --no-modify-path --profile minimal --default-toolchain $RUST_VER
[ -x "$(command -v cargo)" ] || source "$CARGO_HOME/env"
[ -x "$(command -v cargo)" ] || (echo "cargo not found"; exit 1)
rustup override set $RUST_VER # temporary override for this dir

# Create module file

echo "-- Modulefile for $PROGRAM_NAME.
local root_dir = '$INSTALL_DIR'
if (mode() ~= 'whatis') then
    prepend_path('PATH', root_dir .. '/bin')
    prepend_path('LD_LIBRARY_PATH', root_dir .. '/lib')
    prepend_path('LD_LIBRARY_PATH', root_dir .. '/lib64')
    prepend_path('LIBRARY_PATH', root_dir .. '/lib')
    prepend_path('LIBRARY_PATH', root_dir .. '/lib64')
    prepend_path('CPATH', root_dir .. '/include')
    setenv('CARGO_HOME', os.getenv('MYSCRATCH') .. '/.cargo')
    setenv('RUSTUP_HOME', '$INSTALL_DIR_PREFIX')
end
    " > "$MODULEFILE_DIR/${PROGRAM_VERSION}.lua"


