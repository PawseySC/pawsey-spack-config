# Zeus test deployment

Spack branch: releases/v0.16

Test environments:
1. Computational Chemistry
2. Python
3. Clingo (with view)

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

Clingo installation
* Using an environment with view, as per Spack Github issue
* There is an environment YAML for clingo under `environment3_clingo/`
* Once installed, start a new shell session, and use clingo with:
  ```
  spackdir="<PATH TO SPACK INSTALLATION>"
  viewdir="<PATH TO VIEW DIR>"
  export PATH=$viewdir/bin:$PATH
  export PYTHONPATH=$viewdir/lib/python3.9/site-packages:$PYTHONPATH
  . $spackdir/share/spack/setup-env.sh
  ```
  * Note how you need to ensure that the Python used to install Clingo 
    is configured in the shell prior to sourcing the Spack script
  * This implies that, if a host Python is used rather than a Spack installed one, 
    this one needs to be in the shell, *e.g.* by means of a `module load` if applicable

