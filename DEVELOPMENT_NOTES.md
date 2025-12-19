# Development Notes (19-12-25)

## Initial Setup

1) First, set up the environment:

```bash
#!/bin/bash

export INSTALL_GROUP="pawsey0001"
export INSTALL_PREFIX="${MYSCRATCH}/setonix-q-tests"
export SYSTEM="setonix-q"
export DATE_TAG="2025.08"

mkdir -p "${INSTALL_PREFIX}"

module load PrgEnv-nvidia gcc-native-mixed/12.3 craype craype-arm-grace craype-network-ofi xpmem
module unload cray-libsci
````

2. Then source the helper functions:

```bash
source scripts/pawsey_software_stack_funcs.sh
```

3. Once Spack is installed, initialise it:

```bash
. "${INSTALL_PREFIX}/${DATE_TAG}/spack/share/spack/setup-env.sh"
```
