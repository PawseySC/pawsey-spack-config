# Lmod arch family fix for the module tree
patch $SPACK_ROOT/lib/spack/spack/modules/lmod.py lmod_arch_family.patch
# Enhancements to modulefiles
patch $SPACK_ROOT/lib/spack/spack/modules/common.py modulenames_plus_common.patch
patch $SPACK_ROOT/lib/spack/spack/cmd/modules/__init__.py modulenames_plus_init.patch
