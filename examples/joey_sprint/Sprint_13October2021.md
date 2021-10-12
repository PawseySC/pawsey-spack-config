## Joey sprint - 13 October 2021


### Setup notes
- starting point: https://github.com/PawseySC/pawsey-spack-config/tree/main/examples/joey_sprint
- always use module "cray-python" for python
- using spack develop branch from "pawseysc/spack" (controlled sync)
- note: spack now uses the Clingo concretiser
  - some behaviours may differ from previous sprint (especially when concretising)
- have a quick look to "packages.yaml" to have an idea of which packages are external/not buildable
  - always use latest cmake@3.21.3 (external)
  - fftw@2.1.5 also provided as external
  - some externals are commented out due to missing headers: bzip2, hwloc, libxml2, ncurses
  - Cray libraries "should" now work


### Focus on gcc
- try all assigned packages
- start and analyse/solve errors
- examples of typical errors on Confluence
  - **https://support.pawsey.org.au/documentation/display/PSSI/Spack+on+Joey**
  - "buildable false" error (misleading)
  - missing headers in external packages
  - older cmakes such as system one (use latest!)
  - fftw-api error
  - possible hdf5 API errors (6/8, 10, 12)
  - cray-libsci in scipy is a good example where cray was not accounted for
  - llvm possibly not building (C++ header not found)


### Desired outputs
  - take notes of what you are getting
  - report significant notes on Confluence
    - **https://support.pawsey.org.au/documentation/display/PSSI/Spack+on+Joey**
  - report system library requirements (eg -dev) on Jira
    - **https://support.pawsey.org.au/portal/browse/IS-2574**
  - branch "pawsey-spack-config" and add edited recipes
    - **https://github.com/PawseySC/pawsey-spack-config**


### Out of scope
  - move to aocc (and cce) only if time allows
    - cce: do not use for benchmarks until November (zen3 not supp)
  - arch optimisation not relevant today (zen2 vs zen3)
  - benchmarks later on
    - some caveats with zen3 (Pascal)

