# Copyright 2013-2024 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: added py-symengine 0.11.0 and 0.13.0 (built from the GitHub archive,
# as the PyPI sdist lacks the required cmake directory) to satisfy py-qiskit's
# requirement of py-symengine@0.11:0.13.

from spack.package import *


class PySymengine(PythonPackage):
    """Python wrappers for SymEngine, a symbolic manipulation library."""

    homepage = "https://github.com/symengine/symengine.py"
    pypi = "symengine/symengine-0.2.0.tar.gz"
    git = "https://github.com/symengine/symengine.py.git"

    license("MIT")

    version("master", branch="master")
    # pypi source doesn't have necessary files in cmake directory, so the
    # GitHub archive is used for all but the very old releases below.
    version(
        "0.13.0",
        url="https://github.com/symengine/symengine.py/archive/refs/tags/v0.13.0.tar.gz",
        sha256="fa48beb9b8d4574482edf19dc8671d4cb78f53c2511047a0e52bb88fbdeb6d0c",
    )
    version(
        "0.11.0",
        url="https://github.com/symengine/symengine.py/archive/refs/tags/v0.11.0.tar.gz",
        sha256="702fc5e5640e81714eacecf9da03ba1d9cc2f49fc8c4c6154b57d3d7dfacc698",
    )
    version("0.9.2", sha256="0f7e45f5bba3fa844f7de7aa8d6640faaacb1075df76d8e4996e82b0ec6a4f62")
    version(
        "0.8.1",
        url="https://github.com/symengine/symengine.py/archive/refs/tags/v0.8.1.tar.gz",
        sha256="02fe79e6d5e9b39a1d4e6fee05a2c1d1b10fd032157c7738ed97e32406ffb087",
    )
    version("0.2.0", sha256="78a14aea7aad5e7cbfb5cabe141581f9bba30e3c319690e5db8ad99fdf2d8885")

    depends_on("cxx", type="build")  # generated

    # Build dependencies
    depends_on("python@2.7:2.8,3.3:", type=("build", "run"), when="@0.2.0")
    depends_on("python@3.6:3", type=("build", "run"), when="@0.8.1:")
    depends_on("python@3.7:3", type=("build", "run"), when="@0.9.2:")
    depends_on("python@3.8:3", type=("build", "run"), when="@0.11:")
    depends_on("py-setuptools", type="build")
    # https://github.com/symengine/symengine.py/issues/429
    depends_on("py-setuptools@:60", type="build", when="@:0.9.2")
    depends_on("py-cython@0.19.1:", type="build", when="@0.2.0")
    depends_on("py-cython@0.29.24:", type="build", when="@0.8.1:")
    # in newer pip versions --install-option does not exist
    depends_on("py-pip@:23.0", type="build")
    depends_on("cmake@2.8.12:", type="build")
    # see symengine_version.txt
    depends_on("symengine@0.2.0", when="@0.2.0")
    depends_on("symengine@0.8.1", when="@0.8.1")
    depends_on("symengine@0.9.0", when="@0.9.2")
    depends_on("symengine@0.11.1", when="@0.11.0")
    depends_on("symengine@0.13.0", when="@0.13.0")
    depends_on("symengine@master", when="@master")

    def install_options(self, spec, prefix):
        return ["--symengine-dir={0}".format(spec["symengine"].prefix)]
