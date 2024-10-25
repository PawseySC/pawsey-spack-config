# Repositories

This directory contains Pawsey (and Setonix/HPE Cray EX) specific updates to existing recipes or 
recipes that are not yet part of the spack repository. The information contained in this recipe 
is not exhaustive but here to highlight some specifics. 

This is current as of 22/06/2023. 

## Updates to existing recipes

Recipes that exist in spack/0.19.0 but that have updates here contain comments at the top of 
the recipe containing a simple description of the update and a diff. Some files contain minimal 
changes to the recipe but have a large number of and/or significant patches. 

The file `package_diffs_vs_spack_0.17.txt` contains the diff between our packages and the ones in the official Spack repository.

Please look at the head comments for the packages to see if the recipe is fit for purpose for your installation. 

## New recipes 

Some recipes are yet to be part of the spack repository. A number of them are radio astronomy focused. 

Here is a list of packages we developed and not included in Spack 0.17.0:

- ansys-fluids
- ansys-fluidstructures
- ansys-structures
- everybeam
- idg
- miniocli
- py-erfa
- tower-agent
- tower-cli
- wcstools
- wsclean


Please look at the head comments for the packages to see if the recipe is fit for purpose for your installation.
