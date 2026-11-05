# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipsparse(HipMathPackage):
    """HIP sparse-matrix interfaces backed by NVIDIA cuSPARSE."""

    libraries = ["libhipsparse"]

    def cmake_args(self):
        args = super().cmake_args()
        if self.spec.satisfies("@7.2.4"):
            args += [self.define("USE_CUDA", True), self.define("BUILD_CLIENTS_BENCHMARKS", False)]
        else:
            args += [self.define("HIPSPARSE_ENABLE_CUDA", True), self.define("HIPSPARSE_ENABLE_HIP", False)]
        return args
