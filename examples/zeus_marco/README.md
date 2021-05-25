# Zeus test deployment

Test environments:
1. Computational Chemistry
2. Python

The idea is to re-use a number of tools from the host system (providers are defined, too):
* System GCC
* Default GCC
* Open MPI
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
* Adding suffix for Open MPI
* Loading dependency modules for applications needing Python
* Adding *_HOME* variable
