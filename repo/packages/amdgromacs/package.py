# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Pawsey, Ilkhom: 1) replaced f"-D HIP_HIPCC_FLAGS='-O3 --amdgpu-target={amdgpu_target} --save-temps -I/opt/cray/pe/mpich/8.1.30/ofi/gnu/12.3/include/'" with 
#                          f"-D HIP_HIPCC_FLAGS='-O3 -I/opt/rocm-6.1.3/include/hipfft --offload-arch={amdgpu_target} --save-temps -I/opt/cray/pe/mpich/8.1.30/ofi/gnu/12.3/include/'" 
# cmake was not able to find /opt/rocm-6.1.3/include/hipfft
# --amdgpu-target is deprecated in rocm/6.1.3
#                 2) patch("fix_hip_add_library.patch"): this is to set the new path of FindHIP.cmake to /opt/rocm-6.1.3/lib/cmake/hip/FindHIP.cmake
#                 3) patch("fix_memoryAttributes.patch"): this is to replace 
#                    isPinned = (memoryAttributes.memoryType == hipMemoryTypeHost); with
#                    isPinned = (memoryAttributes.isManaged == 0);

from spack.package import *
from spack.util.prefix import Prefix

class Amdgromacs(CMakePackage, ROCmPackage):
    """
    AMD port of Gromacs.
    """

    homepage = "https://github.com/ROCmSoftwarePlatform/Gromacs"
    git = "https://github.com/ROCmSoftwarePlatform/Gromacs.git"

    maintainers = ["cdipietrantonio","Ilkhom"]
    
    # Even though the branch is develop_2022_amd, the version string printed by gmx_mpi
    # is the following one:
    # GROMACS - gmx mdrun, 2023-dev-commit;ba2dd6f6d70 
    #version("2023", commit="ba2dd6f6d709cc4d4c1083024838e2082e72f3b1")
    version("2023", commit="7bbbb2de208ac1a42c7144ac28ecc5fb0dc0dd4e")
    # version("2023", branch="develop_2023_amd")
    
    variant("openmp", default=True)
    # variant("plumed", default=False)

#    depends_on("fftw-api@3:")
    depends_on("cray-libsci")
    depends_on("cray-fftw")
#    depends_on("python@3.9:")
#    depends_on("plumed@2.9.0", when="+plumed") # Plumed not supported at the moment
    depends_on("mpi")
    depends_on("hwloc")
    
    patch("fix_hip_add_library.patch")
    patch("fix_memoryAttributes.patch")

#    def patch(self):
#        plumed = Executable(self.spec["plumed"].prefix.bin.plumed)
#        plumed("patch", "-p", "-e", f"gromacs-{self.spec.version}", "-m", "shared")
         
    def cmake_args(self):
#        hipcc = self.spec["hip"].prefix.bin.hipcc
        amdgpu_target = ",".join(self.spec.variants["amdgpu_target"].value)
        
#        args = [
#            "-D CMAKE_BUILD_TYPE=Release", "-D CMAKE_C_COMPILER=/opt/cray/pe/craype/2.7.20/bin/cc",
#            "-D CMAKE_CXX_COMPILER=/opt/cray/pe/craype/2.7.20/bin/CC", "-D GMX_OPENMP=ON",
#            "-D GMX_MPI=ON","-D GMX_GPU=HIP",
#            f"-D CMAKE_HIP_ARCHITECTURES={amdgpu_target}", f"-D AMDGPU_TARGETS={amdgpu_target}",
#            f"-D HIP_HIPCC_FLAGS='-O3 --amdgpu-target={amdgpu_target} --save-temps -I/opt/cray/pe/mpich/8.1.25/ofi/gnu/9.1/include'",
#	        "-D GMX_GPU_USE_VKFFT=ON", "-D CMAKE_C_FLAGS='-Ofast'",
#            "-D CMAKE_CXX_FLAGS='-Ofast'", 
#            "-D GMX_SIMD=AVX2_256",
#            "-D GMX_SIMD=AVX2_256", 
#            "-D CMAKE_EXE_LINKER_FLAGS='-fopenmp'",
#            "-D GMX_BUILD_FOR_COVERAGE=OFF",
#            "-D GMX_EXTERNAL_LAPACK=ON", 
#            "-D GMX_EXTERNAL_BLAS=ON",
#            f"-D GMX_BLAS_USER=/opt/cray/pe/libsci/23.02.1.1/GNU/9.1/x86_64/lib/libsci_gnu.so",
#            f"-D GMX_LAPACK_USER=/opt/cray/pe/libsci/23.02.1.1/GNU/9.1/x86_64/lib/libsci_gnu.so",
#            "-D BUILD_SHARED_LIBS=OFF",
#            "-D GMX_DOUBLE=OFF",
#            f"-D CMAKE_CXX_LINK_FLAGS=-I/opt/cray/pe/mpich/8.1.25/ofi/gnu/9.1/include",
#            f"-D HIP_CLANG_PARALLEL_BUILD_LINK_OPTIONS=-I/opt/cray/pe/mpich/8.1.25/ofi/gnu/9.1/include",
#            "-D HIP_VERBOSE_BUILD=ON",
#            "-D CMAKE_VERBOSE_MAKEFILE=ON"
#        ]

        args = [
            "-DCMAKE_BUILD_TYPE=Release",
            "-DCMAKE_C_COMPILER=cc",
            "-DCMAKE_CXX_COMPILER=CC",
            "-DGMX_OPENMP=ON",
            "-DGMX_MPI=ON",
            "-DGMX_GPU=HIP",
            "-DCMAKE_HIP_ARCHITECTURES='gfx90a'",
            "-DAMDGPU_TARGETS='gfx90a'",
            "-DGPU_TARGETS='gfx90a'",
            f"-D HIP_HIPCC_FLAGS='-O3 -I/opt/rocm-6.3.0/include/hipfft --offload-arch={amdgpu_target} --save-temps -I/opt/cray/pe/mpich/8.1.32/ofi/gnu/12.3/include/'",
            "-DGMX_GPU_USE_VKFFT=ON",
            "-DCMAKE_C_FLAGS='-Ofast'",
            "-DCMAKE_CXX_FLAGS='-Ofast'", 
            "-DGMX_SIMD=AVX2_256",
            "-DCMAKE_EXE_LINKER_FLAGS='-fopenmp'",
            "-DGMX_BUILD_FOR_COVERAGE=OFF",
            "-DGMX_EXTERNAL_LAPACK=ON",
            "-DGMX_EXTERNAL_BLAS=ON",
            f'-DGMX_BLAS_USER={self.spec["cray-libsci"].prefix}/lib/libsci_gnu.so',
            f'-DGMX_LAPACK_USER={self.spec["cray-libsci"].prefix}/lib/libsci_gnu.so',
            "-DBUILD_SHARED_LIBS=OFF",
            "-DGMX_DOUBLE=OFF",
            f'-D CMAKE_CXX_LINK_FLAGS=-I{self.spec["cray-mpich"].prefix}/include',
            f'-D HIP_CLANG_PARALLEL_BUILD_LINK_OPTIONS=-I{self.spec["cray-mpich"].prefix}/include',
            "-DHIP_VERBOSE_BUILD=ON",
            "-DCMAKE_VERBOSE_MAKEFILE=ON"
        ]


#            f"-DGMX_BLAS_USER=/opt/cray/pe/libsci/23.02.1.1/GNU/9.1/x86_64/lib/libsci_gnu.so",
#            f"-DGMX_LAPACK_USER=/opt/cray/pe/libsci/23.02.1.1/GNU/9.1/x86_64/lib/libsci_gnu.so",
#            f"-D HIP_CLANG_PARALLEL_BUILD_LINK_OPTIONS=-I/opt/cray/pe/mpich/8.1.25/ofi/gnu/9.1/include",

#            "-DCMAKE_CXX_LINK_FLAGS=-I$CRAY_MPICH_PREFIX/include",
#            "-DHIP_CLANG_PARALLEL_BUILD_LINK_OPTIONS=-I$CRAY_MPICH_PREFIX/include",
#            "-DHIP_HIPCC_FLAGS='-O3 --amdgpu-target=gfx90a --save-temps -I$CRAY_MPICH_PREFIX/include'",

        if '+openmp' in self.spec:
            args.extend(["-DCMAKE_EXE_LINKER_FLAGS=-fopenmp", "-DGMX_OPENMP=ON"])

        return args

    def get_paths(self):
        rocm_spec = self.spec["hip"]
        rocm_prefix = Prefix(rocm_spec.prefix)

        paths = {
            "hip-path": rocm_spec.prefix,
            "rocm-path": rocm_spec.prefix,
            "rocm-device-libs": rocm_spec.prefix, #rocm_prefix, #elf.spec["llvm-amdgpu"].prefix,
            "llvm-amdgpu": rocm_prefix.llvm,
            "hsa-rocr-dev": rocm_prefix.hsa,
        }
        paths["bitcode"] = paths["rocm-device-libs"].amdgcn.bitcode

        return paths

    def set_variables(self, env):
        if self.spec.satisfies("+rocm"):
            # Note: do not use self.spec[name] here, since not all dependencies
            # have defined prefixes when hip is marked as external.
            paths = self.get_paths()

            # Used in hipcc, but only useful when hip is external, since only then
            # there is a common prefix /opt/rocm-x.y.z.
            env.set("ROCM_PATH", paths["rocm-path"])
            # Just the prefix of hip (used in hipcc)
            env.set("HIP_PATH", paths["hip-path"])
            env.set("HIP_DEVICE_LIB_PATH", paths["bitcode"])
            env.set("HIP_CLANG_PATH", paths["llvm-amdgpu"].bin)
            env.set("HSA_PATH", paths["hsa-rocr-dev"])
            env.set("DEVICE_LIB_PATH", paths["bitcode"])
            env.set("LLVM_PATH", paths["llvm-amdgpu"])

            env.append_path(
                "HIPCC_COMPILE_FLAGS_APPEND",
                "--rocm-path={0}".format(paths["rocm-path"]),
                separator=" ",
            )


    def setup_build_environment(self, env):
        if self.spec.satisfies("+rocm"):      
            self.set_variables(env)

    def setup_run_environment(self, env):
        if self.spec.satisfies("+rocm"):
            self.set_variables(env)    
