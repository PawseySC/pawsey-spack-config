#!/bin/bash

echo "Installing quantum packages"
names=(
pennylane-source-omp-setonix-q \
pennylane-source-setonix-q \
qiskit-source-mpi-omp-setonix-q \
pennylane-source-hip-setonix-q \
qiskit-source-rocm-setonix-q)

for n in ${names[@]}
do
    ./install-${n}.sh
done