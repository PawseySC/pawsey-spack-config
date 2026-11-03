# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack.package import *


class PyCudaCore(PythonPackage):
    """Pythonic CUDA interfaces provided by NVIDIA CUDA Core."""

    homepage = "https://nvidia.github.io/cuda-python/cuda-core/"
    url = "https://github.com/NVIDIA/cuda-python/archive/refs/tags/cuda-core-v0.3.2.tar.gz"

    license("Apache-2.0")

    version("0.3.2", sha256="ef6898e81cd81c1ba0e16278d25192615bc69acc558cd036947847617fd09e95")

    depends_on("cxx", type="build")
    depends_on("python@3.9:", type=("build", "run"))
    depends_on("py-setuptools@77:", type="build")
    depends_on("py-cython@3.0:", type="build")
    depends_on("py-numpy", type="run")
    depends_on("py-cuda-bindings@11.8:13", type="run")

    build_directory = "cuda_core"
