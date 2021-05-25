# Zeus test deployment

Test environment:
1. Computational Chemistry

The idea is to re-use a number of tools from the host system (providers are defined, too):
* System GCC
* Default GCC
* CUDA
* gdrcopy
* ucx
* Open MPI (depends on CUDA, gdrcopy, ucx)
* Intel MKL

Spack configuration:
* Redefining some config paths, to ensure the *HOME* directory is never used 
* For production, `source_cache` should probably be shared in some explicit system path
* Not sure yet about `misc_cache`

Experimenting with module files:
* Using TCL syntax
* Creating module files for *all* installed packages
* Hard-coding subdirectories for applications (for classification purposes)
* Using compiler name/version in module name
* Black-listing host packages
* Adding suffix for Open MPI and CUDA
* Loading dependency modules for applications needing Python
* Adding *_HOME* variable
