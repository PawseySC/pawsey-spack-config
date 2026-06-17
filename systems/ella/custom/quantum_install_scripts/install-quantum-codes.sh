#!/bin/bash

echo "Installing quantum packages"
names=(
pennylane-source-omp-setonix \
pennylane-source-setonix \
qiskit-source-mpi-omp-setonix \
pennylane-source-hip-setonix \
qiskit-source-rocm-setonix)

for n in ${names[@]}
do
    ./install-${n}.sh
done