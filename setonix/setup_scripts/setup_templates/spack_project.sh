#!/bin/bash

# enable group access and writing to the stack
umask g+rwx

# use spack configs for project-wide setup
spack -C ROOT_DIR/spack/etc/spack/project_allusers $@
