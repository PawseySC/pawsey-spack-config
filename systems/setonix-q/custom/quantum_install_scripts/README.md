# Quantum Software Installation Scripts

This directory contains custom installation scripts for quantum computing packages on Setonix-Q.

## Modules

The following Python packages are installed with the `py-` prefix convention:

| Module | Description |
|--------|-------------|
| `py-qiskit` | Qiskit quantum computing SDK with Aer GPU simulator (CUDA + cuQuantum + MPI) |
| `py-pennylane` | PennyLane quantum ML framework with Lightning-GPU/Tensor backends |
| `py-pennylane-qiskit` | PennyLane-Qiskit plugin for using Qiskit backends in PennyLane |

## Package Directories

Each package has its own directory with:
- `use.sh` - Configuration variables (versions, dependencies, paths)
- `install.sh` - Build and installation logic
- `module.lua` - Lmod module template

## Installation

Setup the environment:

```bash
module purge
module load pawsey pawseyenv pawseytools
module load PrgEnv-gnu-nvidia
source ././settings.sh # settings for setonix-q

```

Run individual package installers:
```bash
./qiskit/install.sh
./pennylane/install.sh
./pennylane-qiskit/install.sh
```

Or use the master script (requires appropriate compute node):
```bash
./install-quantum-codes.sh
```

## Utilities

- `utils.sh` - Common functions used by all install scripts
