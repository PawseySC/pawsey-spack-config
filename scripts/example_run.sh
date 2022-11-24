#!/bin/bash

module load spack/0.17.0

spack spec nano

# "spack" user uses "spack" group (default)
# for all other users, need sg $PAWSEY_PROJECT -c '<bla>'
spack install nano
