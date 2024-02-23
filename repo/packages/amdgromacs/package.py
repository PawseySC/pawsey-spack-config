# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.util.prefix import Prefix

class Amdgromacs(CMakePackage, ROCmPackage):
    """
    AMD port of Gromacs.
    """

    homepage = "https://github.com/ROCmSoftwarePlatform/Gromacs"
    git = "https://github.com/ROCmSoftwarePlatform/Gromacs.git"

    maintainers = ["cdipietrantonio"]
    
    # Even though the branch is develop_2022_amd, the version string printed by gmx_mpi
    # is the following one:
    # GROMACS - gmx mdrun, 2023-dev-commit;ba2dd6f6d70 
    version("2023", commit="ba2dd6f6d709cc4d4c1083024838e2082e72f3b1")
    # version("2023", branch="develop_2023_amd")
    
    variant("openmp", default=True)
    # variant("plumed", default=False)

    depends_on("fftw-api@3:")
    depends_on("python@3.9:")
#    depends_on("plumed@2.9.0", when="+plumed") # Plumed not supported at the moment
    depends_on("mpi")
    depends_on("hwloc")
    

#    def patch(self):
#        plumed = Executable(self.spec["plumed"].prefix.bin.plumed)
#        plumed("patch", "-p", "-e", f"gromacs-{self.spec.version}", "-m", "shared")
         
    def cmake_args(self):
        hipcc = self.spec["hip"].prefix.bin.hipcc
        amdgpu_target = ",".join(self.spec.variants["amdgpu_target"].value)
        
        args = [
            "-DBUILD_SHARED_LIBS=on", "-DMPI_C_LIB_NAMES=mpi",
            "-DMPI_CXX_LIB_NAMES=mpi", f"-DMPI_mpi_LIBRARY={self.spec['mpi'].prefix.lib}/libmpi.so",
            "-DGMX_BUILD_OWN_FFTW=OFF","-DGMX_BUILD_FOR_COVERAGE=off",
            f"-DCMAKE_C_COMPILER={hipcc}", f"-DCMAKE_CXX_COMPILER={hipcc}",
	        f"-DMPI_CXX_COMPILER={self.spec['mpi'].mpicxx}", f"-DMPI_C_COMPILER={self.spec['mpi'].mpicc}",
            "-DGMX_MPI=on", "-DGMX_GPU=HIP",
            self.define_from_variant("CMAKE_HIP_ARCHITECTURES", "amdgpu_target"),
            "-DGMX_SIMD=AVX2_256", "-DREGRESSIONTEST_DOWNLOAD=OFF",
            "-DGMX_GPU_USE_VKFFT=on",
            f"-DHIP_HIPCC_FLAGS=-O3 --amdgpu-target={amdgpu_target} --save-temps",
            "-DGMX_HWLOC=ON", "-DMPIEXEC=srun",
		    "-DMPIEXEC_NUMPROC_FLAG=-n", 
        ]

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
        self.set_variables(env)

    def setup_run_environment(self, env):
        self.set_variables(env)    
