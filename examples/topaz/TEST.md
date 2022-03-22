# Topaz test deployment

Spack branch: `v0.17.0`

## Test environment:

1. Computational Chemistry

The idea is to re-use a number of tools from the host system (providers are defined, too):
* System GCC
* Default GCC
* CUDA
* gdrcopy
* ucx
* Open MPI (depends on CUDA, gdrcopy, ucx)
* Intel MKL

## Spack configuration:
* Redefining some config paths, to ensure the *HOME* directory is never used 
* For production, `source_cache` should probably be shared in some explicit system path
* Not sure yet about `misc_cache`
* Has patches to be applied to spack modules (see `fixes/`)
