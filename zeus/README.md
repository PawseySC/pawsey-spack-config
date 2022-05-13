# Zeus test deployment

Spack branch: releases/v0.17

## Issues:

The are issues using spack on zeus due to the file locks used by spack. Currently as of 23/02/2022 it is not possible to place a lock on `/pawsey/sles12sp3/` where software should be installed to. The inability to lock results in an error when running `spack spec` and `spack install`:

```bash
OSError: [Errno 37] No locks available
```
## Current Setup

### Test environments:

1. Computational Chemistry
2. Python
3. Clingo (with view)

The idea is to re-use a number of tools from the host system (providers are defined, too):
* System GCC
* Default GCC
* Open MPI
* Intel MKL

#### Spack configuration:

* Redefining some config paths, to ensure the *HOME* directory is never used 
* For production, `source_cache` should probably be shared in some explicit system path
* Not sure yet about `misc_cache`
* Has patches to be applied to spack modules (see `fixes/`)


### Clingo installation

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
  * This implies that, if a host Python is used rather than a Spack installed 
    one, this one needs to be in the shell, *e.g.* by means of a 
    `module load` if applicable

