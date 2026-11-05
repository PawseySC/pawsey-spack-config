# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hiprand(HipMathPackage):
    """HIP random number generation backed by NVIDIA cuRAND."""

    license("MIT")

    def cmake_args(self):
        args = super().cmake_args() + [
            self.define("BUILD_WITH_LIB", "CUDA"),
            self.define("BUILD_TEST", False),
            self.define("BUILD_BENCHMARK", False),
        ]
        if self.spec.variants["cuda_arch"].value != ("none",):
            args.append(self.define("NVGPU_TARGETS", self.spec.variants["cuda_arch"].value))
        return args
