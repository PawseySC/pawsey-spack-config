# Quantum Software Installation Scripts

Installation scripts for quantum computing packages on Setonix-Q.

## Installed Modules

| Module | Description |
|--------|-------------|
| `cutensor` | NVIDIA cuTENSOR - GPU tensor linear algebra |
| `cuquantum` | NVIDIA cuQuantum SDK - GPU quantum simulation |
| `py-mpi4py` | MPI for Python with GPU-aware support (via Spack) |
| `py-qiskit` | Qiskit with Aer GPU simulator (CUDA + cuQuantum + MPI) |
| `py-qiskit-nompi` | Qiskit with Aer GPU simulator (no MPI) |
| `py-pennylane` | PennyLane with Lightning-GPU/Tensor backends |
| `py-pennylane-qiskit` | PennyLane-Qiskit plugin (uses py-qiskit-nompi) |

## Installation

```bash
module purge
module load pawsey pawseyenv pawseytools PrgEnv-gnu-nvidia
source ../settings.sh
./install-quantum-codes.sh
```

Or run individual installers: `./qiskit/install.sh`, etc.

## Structure

Each package directory contains:
- `use.sh` - Configuration (versions, dependencies)
- `install.sh` - Build logic
- `module.lua` - Module template

Common functions in `utils.sh`.
