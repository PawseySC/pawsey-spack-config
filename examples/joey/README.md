#Joey early tests

The goal of these tests is to get ready for the team sprints.  

Spack branch: develop  
Spack commit hash: 2d1ebbe0a2b0ebf33cfdcfad7324572ef95f992b  
Spack commit date: 30 Sep 2021   

Configuration files:
* custom compilers and packages
  * seem to work with Cray MPI, FFTW, HDF5 and NetCDF
* custom config
  * just to keep paths simple
* custom modules
  * borrowed from zeus/magnus tests
  * not used yet

Setup:
```
$ module load cray-python
$ . ~/spack/share/spack/setup-env.sh
```

Test environments:
1. Clingo with Spack Python
2. Clingo with host Python (will use cray-python module by default)
3. FFTW2 to overcome buildable-false
4. Computational Chemistry
5. Python
