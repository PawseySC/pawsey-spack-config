-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : PACKAGE_NAME-dependency-set]])
whatis([[Package version and spec used to generate deps: PACKAGE_SPEC ]])

whatis([[Short description : Meta module to load dependencies to build PACKAGE_NAME@PACKAGE_VERSION. ]])
help([[Meta module that loads all dependencies need to build local PACKAGE_NAME@PACKAGE_VERSION]])

-- TODO: figure out way of spack generating dependencies
-- currently would be to make use of the spack.lock 
-- in the related environment. 
