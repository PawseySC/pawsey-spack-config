# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Modified/backported the Spack py-autoray recipe with 0.8.4 support
# for PennyLane 0.45.

from spack.package import *


class PyAutoray(PythonPackage):
    """Abstract your array operations."""

    homepage = "https://github.com/jcmgray/autoray"
    pypi = "autoray/autoray-0.8.4.tar.gz"

    license("Apache-2.0")

    version("0.8.4", sha256="b4ce7066334279b216431a260bb5b5b84d87815e3295020a76d8701e43dc3432")

    depends_on("python@3.10:", type=("build", "run"))
    depends_on("py-hatchling", type="build")
    depends_on("py-hatch-vcs", type="build")
