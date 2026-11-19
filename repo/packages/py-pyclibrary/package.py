# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack.package import *


class PyPyclibrary(PythonPackage):
    """C binding automation."""

    homepage = "https://github.com/MatthieuDartiailh/pyclibrary"
    pypi = "pyclibrary/pyclibrary-0.3.0.tar.gz"

    license("MIT")

    version("0.3.0", sha256="8a3eaa9ab728c11b077644275af4e05ca24ddcad491f47eb45b75db6be52c654")

    depends_on("python@3.10:", type=("build", "run"))
    depends_on("py-setuptools@61.2:", type="build")
    depends_on("py-setuptools-scm@3.4.3:", type="build")
    depends_on("py-wheel", type="build")
    depends_on("py-pyparsing@2.3.1:3", type=("build", "run"))
