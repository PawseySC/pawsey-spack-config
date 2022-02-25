# Installation Scripts 

## Issues
Current zeus setup results in spack encountering file lock issues for the nas mounted `/pawsey` file system. 

To address this issue, the config for zeus installs to 
`/group/pawsey0001/maali/software/sles12sp3/spack/software/`

Modules are also produced in `/group/pawsey0001/maali/software/sles12sp3/spack/modulefiles/`

The modules produced in a convention that follows what is outlined in Setonix. This does not conform to the 
paths and naming convention used on Pre-Setonix systems. This may change but currently that means that module 
files need to be updated once moved to the standard module paths. It also means that no hierarchy can be present since
this is not used on zeus. 

To that end, this directory contains scripts that update both modules and software to be used. 

## List of scripts 

The scripts alter the software, specifically they correct the rpath, and also update modules 

- `zeus_fix_rpath.sh` : uses readelf and patchelf (installed by spack) to fix the rpath 
- `zeus_fix_modulepath.sh` : Fix the paths listed in the module 
