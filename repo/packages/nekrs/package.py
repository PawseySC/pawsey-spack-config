# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os


class Nekrs(CMakePackage, ROCmPackage):
    """High-order methods have the potential to overcome the current limitations of standard CFD solvers. For this reason, we have been developing and improving our spectral element code for more than 35 years now. It features state-of-the-art, scalable algorithms that are fast and efficient on platforms ranging from laptops to the world’s fastest computers. Applications span a wide range of fields, including fluid flow, thermal convection, combustion and magnetohydrodynamics. Our user community includes hundreds of scientists and engineers in academia, laboratories and industry."""

    homepage = 'https://nek5000.mcs.anl.gov/'
    url      = 'https://github.com/Nek5000/nekRS/archive/refs/tags/v22.0.tar.gz'
    git      = 'https://github.com/Nek5000/nekRS.git'
    maintainers = ['Basha', 'crist']

    version("23.0",tag="v23.0")
    version("22.0",tag="v22.0")

    variant('rocm', default=True, description='Enable Hip support')
    variant('mpi', default=True, description='Enable mpi support')

    depends_on('hip')
    depends_on('mpi')

    def cmake_args(self):
        args = []

        args.append('-DENABLE_CUDA=0')
        args.append('-DENABLE_HIP=1')
        args.append('-DENABLE_OPENCL=0')
        args.append('-DGPU_MPI=1')
        args.append('-DAMDGPU_TARGET=gfx90a')

        return args

    def setup_run_environment(self, env):
        spec = self.spec
        env.set("OCCA_CXX", self.compiler.cxx)
        cxxflags = spec.compiler_flags["cxxflags"]
        env.set("OCCA_CXXFLAGS", " ".join(cxxflags))
        env.set("NEKRS_HOME", self.prefix)


    def setup_build_environment(self, env):
        spec = self.spec
        rocm_dir = spec["hip"].prefix

        env.set("OCCA_INCLUDE_PATH", rocm_dir.include)
        env.set("OCCA_LIBRARY_PATH", ":".join(rocm_dir.directories))
        env.set("NEKRS_INSTALL_DIR", self.prefix)
        env.set("OCCA_CXX", "CC")
        env.set("OCCA_CXXFLAGS", " ".join(spec.compiler_flags["cxxflags"]))
        env.set("OCCA_ENABLE_HIP","1")
        env.set("CXXFLAGS", " ".join(spec.compiler_flags["cxxflags"]))
        env.set("OCCA_VERBOSE", "1")
        env.set("NEKRS_CC", spec["mpi"].mpicc)
        env.set("NEKRS_CXX", spec["mpi"].mpicxx)
        env.set("NEKRS_FC", spec["mpi"].mpifc)
        env.set("TRAVIS", "true")

