# Lmod arch family fix for the module tree
patch spack/lib/spack/spack/modules/lmod.py pawsey-spack-config/setonix/fixes/lmod_arch_family.patch
# Enhancements to modulefiles
patch spack/lib/spack/spack/modules/common.py pawsey-spack-config/setonix/fixes/modulenames_plus_common.patch
patch spack/lib/spack/spack/cmd/modules/__init__.py pawsey-spack-config/setonix/fixes/modulenames_plus_init.patch
