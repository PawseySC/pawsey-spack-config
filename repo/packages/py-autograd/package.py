# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Modified/backported the Spack py-autograd recipe with 1.8.0 support
# for NumPy 2/PennyLane 0.45.

from spack.package import *


class PyAutograd(PythonPackage):
    """Autograd can automatically differentiate native Python and NumPy code."""

    homepage = "https://github.com/HIPS/autograd"
    pypi = "autograd/autograd-1.8.0.tar.gz"

    license("MIT")

    version("1.8.0", sha256="107374ded5b09fc8643ac925348c0369e7b0e73bbed9565ffd61b8fd04425683")
    version("1.6.2", sha256="8731e08a0c4e389d8695a40072ada4512641c113b6cace8f4cfbe8eb7e9aedeb")
    version("1.6.1", sha256="dd0068f3f78fd76cf28cee94358737c3b5e8a1d2acac0b850e14d14e1bca84ac")
    version("1.6", sha256="b10ad7598bab69251a496210370f7802a21da0ae6a7710197eaae99c3a59b30a")
    version("1.5", sha256="d80bd225154d1db13cb4eaccf7a18c358be72092641b68717f96fcf1d16acd0b")
    version("1.4", sha256="383de0f537ef2e38b85ff9692593b0cfae8958c9b3bd451b52c255fd9171ffce")
    version("1.3", sha256="a15d147577e10de037de3740ca93bfa3b5a7cdfbc34cfb9105429c3580a33ec4")
    version("1.2", sha256="a08bfa6d539b7a56e7c9f4d0881044afbef5e75f324a394c2494de963ea4a47d")

    depends_on("python@3.9:", when="@1.8:", type=("build", "run"))
    depends_on("py-hatchling", when="@1.8:", type="build")
    depends_on("py-setuptools", when="@:1.6", type="build")

    depends_on("py-future@0.15.2:", when="@:1.6", type=("build", "run"))
    depends_on("py-numpy@:2", when="@1.8:", type=("build", "run"))
    depends_on("py-numpy@1.12:", when="@:1.6", type=("build", "run"))
    # https://github.com/HIPS/autograd/releases/tag/v1.7.0
    depends_on("py-numpy@:1", when="@:1.6", type=("build", "run"))
