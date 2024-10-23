# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Just grabbed the latest version from spack/develop
from spack.package import *


class Dftd4(MesonPackage):
    """Generally Applicable Atomic-Charge Dependent London Dispersion Correction"""

    homepage = "https://www.chemie.uni-bonn.de/pctc/mulliken-center/software/dftd4"
    url = "https://github.com/dftd4/dftd4/releases/download/v3.3.0/dftd4-3.3.0-source.tar.xz"
    git = "https://github.com/dftd4/dftd4.git"

    maintainers = ["awvwgk"]

    version("main", branch="main")
    version("3.4.0", "24fcb225cdd5c292ac26f7d3204ee3c4024174adb5272eeda9ae7bc57113ec8d")
    version("3.3.0", "408720b8545532d5240dd743c05d57b140af983192dad6d965b0d79393d0a9ef")
    version("3.2.0", "cef505e091469aa9b8f008ee1756545bb87b02760bb2c7ca54854e20ba8c590a")
    version("3.1.0", "b652aa7cbf8d087c91bcf80f2d5801459ecf89c5d4176ebb39e963ee740ed54b")
    version("3.0.0", "a7539d68d48d851bf37b79e37ea907c9da5eee908d0aa58a0a7dc15f04f8bc35")

    variant("openmp", default=True, description="Use OpenMP parallelisation")
    variant("python", default=False, description="Build Python extension module")

    depends_on("blas")
    depends_on("cmake", type="build")
    depends_on("lapack")
    depends_on("mctc-lib")
    depends_on("meson@0.57.1:", type="build")  # mesonbuild/meson#8377
    depends_on("pkgconfig", type="build")
    depends_on("py-cffi", when="+python")
    depends_on("python@3.6:", when="+python")

    def meson_args(self):
        lapack = self.spec["lapack"].libs.names[0]
        if lapack == "lapack":
            lapack = "netlib"
        elif lapack.startswith("mkl"):
            lapack = "mkl"
        elif lapack != "openblas":
            lapack = "auto"

        return [
            "-Dlapack={0}".format(lapack),
            "-Dopenmp={0}".format(str("+openmp" in self.spec).lower()),
            "-Dpython={0}".format(str("+python" in self.spec).lower()),
        ]
