# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipsolver(HipMathPackage):
    """HIP solver interfaces backed by NVIDIA cuSOLVER."""

    libraries = ["libhipsolver"]

    def cmake_args(self):
        return super().cmake_args() + [
            self.define("USE_CUDA", True),
            self.define("BUILD_FORTRAN_BINDINGS", False),
            self.define("EXPORT_FORTRAN_BINDINGS", False),
        ]
