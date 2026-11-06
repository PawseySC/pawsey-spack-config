# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipblas(HipMathPackage):
    """HIP BLAS interfaces backed by NVIDIA cuBLAS."""

    # LICENSE.md also includes the LAPACK BSD terms with the patent disclaimer.
    license("MIT AND BSD-3-Clause-Open-MPI")
    libraries = ["libhipblas"]
    for ver in ("7.2.4", "10.1.0"):
        depends_on(f"hipblas-common@{ver}", when=f"@{ver}")

    def cmake_args(self):
        return super().cmake_args() + [self.define("USE_CUDA", True)]
