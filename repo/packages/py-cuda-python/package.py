# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack.package import *


class PyCudaPython(PythonPackage):
    """CUDA Python metapackage for CUDA bindings and component discovery."""

    homepage = "https://nvidia.github.io/cuda-python/"
    url = "https://github.com/NVIDIA/cuda-python/archive/refs/tags/v13.0.3.tar.gz"

    license("LicenseRef-NVIDIA-SOFTWARE-LICENSE")

    version(
        "13.1.1",
        sha256="67d3664c91687c2799b9531ca94fb41908857b06b045cdf51343f4176fae63ac",
        url="https://github.com/NVIDIA/cuda-python/archive/refs/tags/v13.1.1.tar.gz",
    )
    version(
        "13.0.3",
        sha256="4885b7898ba30735cdf8a07b52496ecfe2b8f7d119245f3ced190f9ad445ffd4",
        preferred=True,
    )

    build_directory = "cuda_python"

    depends_on("py-setuptools@77:", type="build")
    depends_on("py-cuda-bindings@13.0.3:13.0", when="@13.0.3", type=("build", "run"))
    depends_on("py-cuda-bindings@13.1.1:13.1", when="@13.1.1", type=("build", "run"))
    depends_on("python@3.10:", when="@13.1.1", type=("build", "run"))
    depends_on("py-cuda-pathfinder@1.1:1", type=("build", "run"))
