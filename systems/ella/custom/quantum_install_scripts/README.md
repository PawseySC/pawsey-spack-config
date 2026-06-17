# Installation Scripts

This directory contains custom installation scripts for Pennylane and Qiskit-AER. They may need modification
for proper installation by the spack user. Initial tests indicate that these all of these work but there as 
of yet, we do not have a full reframe set of tests to indicate that these installations are correct. 

## Scripts

There are two main scripts:
- `install-quantum-codes.sh`: run all the individual installation scripts (does require a node in which `rocm` modules are present)
- `install-module.sh`: install a module (called internally by the installation scripts of each package)

These scripts might undergo further updates to clean-up the installation process.




