# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for PennyLane 0.45 runtime dependency.

from spack.package import *


class PyDiastaticMalt(PythonPackage):
    """Diastatic-malt is a fork of TensorFlow AutoGraph."""

    homepage = "https://github.com/PennyLaneAI/diastatic-malt"
    pypi = "diastatic-malt/diastatic-malt-2.15.2.tar.gz"

    license("Apache-2.0")

    version("2.15.2", sha256="7eb90d8c30b7ff16b4e84c3a65de2ff7f5b7b9d0f5cdea23918e747ff7fb5320")

    depends_on("python@3.9:", type=("build", "run"))
    depends_on("py-setuptools", type="build")
    depends_on("py-wheel", type="build")

    depends_on("py-astunparse", type=("build", "run"))
    depends_on("py-gast", type=("build", "run"))
    depends_on("py-termcolor", type=("build", "run"))
