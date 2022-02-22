# Lmod arch family fix for the module tree
patch $spack/lib/spack/spack/modules/lmod.py lmod_arch_family.patch
# Enhancements to modulefiles
patch $spack/lib/spack/spack/modules/common.py modulenames_plus_common.patch
patch $spack/lib/spack/spack/cmd/modules/__init__.py modulenames_plus_init.patch
