# Copyright 2013-2024 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

# Pawsey: local override of the builtin kokkos-nvcc-wrapper 
# The nvcc_wrapper script shipped with kokkos@4.7.04 defaults to sm_80 (valid for CUDA 11-13),
# the 4.4.01 script defaults to sm_70 which CUDA 13 no longer supports.

import os.path

from spack.package import *


class KokkosNvccWrapper(Package):
    """The NVCC wrapper provides a wrapper around NVCC to make it a
    'full' C++ compiler that accepts all flags"""

    # We no longer maintain this as a separate repo
    # Download the Kokkos repo and install from there
    homepage = "https://github.com/kokkos/kokkos"
    git = "https://github.com/kokkos/kokkos.git"
    url = "https://github.com/kokkos/kokkos/releases/download/4.4.01/kokkos-4.4.01.tar.gz"

    maintainers("Rombur")

    license("BSD-3-Clause")

    version("master", branch="master")
    version("develop", branch="develop")

    version("4.7.04", sha256="4213b248c39e112299fa94ee08817e51126fc02996ed6e2ab56aec4cdb80ee1f")
    version("4.4.01", sha256="3413f0cb39912128d91424ebd92e8832009e7eeaf6fa8da58e99b0d37860d972")

    depends_on("cuda")

    def install(self, spec, prefix):
        src = os.path.join("bin", "nvcc_wrapper")
        mkdir(prefix.bin)
        install(src, prefix.bin)

    def setup_dependent_build_environment(self, env, dependent_spec):
        wrapper = join_path(self.prefix.bin, "nvcc_wrapper")
        env.set("CUDA_ROOT", dependent_spec["cuda"].prefix)
        env.set("NVCC_WRAPPER_DEFAULT_COMPILER", self.compiler.cxx)
        env.set("KOKKOS_CXX", self.compiler.cxx)
        env.set("MPICH_CXX", wrapper)
        env.set("OMPI_CXX", wrapper)
        env.set("MPICXX_CXX", wrapper)  # HPE MPT

    @property
    def kokkos_cxx(self):
        return join_path(self.prefix.bin, "nvcc_wrapper")
