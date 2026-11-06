# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipfft(HipMathPackage):
    """HIP FFT interfaces backed by NVIDIA cuFFT and cuFFTW."""

    # LICENSE.md also includes the BSD-licensed CLI11 contribution.
    license("MIT AND BSD-3-Clause")
    libraries = ["libhipfft"]
    patch("cuda-13.patch", when="@7.2.4 ^cuda@13:")

    def cmake_args(self):
        return super().cmake_args() + [self.define("BUILD_WITH_LIB", "CUDA")]
