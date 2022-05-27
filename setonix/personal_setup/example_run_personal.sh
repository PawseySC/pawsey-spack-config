#!/bin/bash

# location of your Spack build
spack_dir="<BLA>"

# use PrgEnv-gnu
module swap PrgEnv-cray/8.3.2 PrgEnv-gnu
# for first run, use cray-python, because there is no Spack python yet
module load cray-python
# initialise spack 
. ${spack_dir}/share/spack/setup-env.sh 

spack spec nano

# remember to install by forcing with your group ownership
sg $PAWSEY_PROJECT -c 'spack install nano'