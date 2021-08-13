# Magnus test deployment

Spack branch: develop

Test environments:
1. AstroComp (maintainer: Pascal)
2. IOComp (maintainer: Pascal)
3. ChemComp (maintainer: Marco)

The idea is to re-use a number of tools from the host system (providers are defined, too):
* System compilers
* Cray mpich

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
* Adding suffix for Cray MPI 
* Loading dependency modules for applications needing Python
* Adding *_HOME* variable

Clingo installation
* Currently develop builds clingo without issue if it is chosen as concretizer
* However, some issues could arise, in which case may be necessary to use an environment with view, as per Spack Github issue
  * Once installed, use it with:
    ```
    viewdir="<PATH TO VIEW DIR>"
    export PATH=$viewdir/bin:$PATH
    export PYTHONPATH=$viewdir/lib/python3.9/site-packages:$PYTHONPATH
    ```

## Notes 



### Running on Magnus 

Due to spack and group permissions, it will be necessary to run spack install commands with the 
appropriate group permission 
```
sg pawsey0001 -c "spack install somepsec" 
```

