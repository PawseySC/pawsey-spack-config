# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class Cccl(CMakePackage):
    """NVIDIA CUB, Thrust and libcu++ headers required by hipCUB."""

    homepage = "https://github.com/NVIDIA/cccl"
    url = "https://github.com/NVIDIA/cccl/archive/refs/tags/v2.8.2.tar.gz"
    version("2.8.2", sha256="141801ddddf5b911f64f97be66a7c75f98374bebca60f275bedec75b8eeab345")
    license("Apache-2.0 WITH LLVM-exception")
    depends_on("cxx", type="build")
    depends_on("cmake@3.21:", type="build")

    def cmake_args(self):
        return [self.define("CMAKE_INSTALL_LIBDIR", "lib")] + [
            self.define("CCCL_ENABLE_" + option, False)
            for option in ("LIBCUDACXX", "CUB", "THRUST", "TESTING", "EXAMPLES")
        ]
