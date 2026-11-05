# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class HipblasCommon(HipMathPackage):
    """Common headers shared by the HIP BLAS interfaces."""

    license("MIT")
