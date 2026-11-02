# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack.package import *


class PyCudaPathfinder(PythonPackage):
    """Utilities for locating CUDA components."""

    homepage = "https://nvidia.github.io/cuda-python/cuda-pathfinder/latest/"
    url = (
        "https://files.pythonhosted.org/packages/py3/c/cuda-pathfinder/"
        "cuda_pathfinder-1.3.4-py3-none-any.whl"
    )
    list_url = "https://pypi.org/simple/cuda-pathfinder/"

    license("Apache-2.0")

    # PyPI only publishes a pure-Python wheel for this release, no sdist.
    version(
        "1.3.4",
        sha256="fb983f6e0d43af27ef486e14d5989b5f904ef45cedf40538bfdcbffa6bb01fb2",
        expand=False,
    )

    depends_on("python@3.10:", type=("build", "run"))
