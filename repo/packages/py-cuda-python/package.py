# Copyright 2013-2026 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class PyCudaPython(PythonPackage):
    """CUDA Python: Performance meets Productivity.

    CUDA Python provides Cython/Python wrappers for CUDA driver and runtime APIs.
    It enables Python developers to access NVIDIA GPU computing capabilities with
    native Python syntax while maintaining near-native performance.

    Installing this package will automatically pull in:
    - cuda-bindings: Low-level CUDA API bindings
    - cuda-pathfinder: CUDA component discovery utilities
    """

    homepage = "https://nvidia.github.io/cuda-python/"
    url = "https://github.com/NVIDIA/cuda-python/archive/refs/tags/v12.9.2.tar.gz"
    git = "https://github.com/NVIDIA/cuda-python.git"

    maintainers("nvidia")

    license("LicenseRef-NVIDIA-SOFTWARE-LICENSE")
    # Sources are multi-project; actual python package lives in cuda_python/
    build_directory = "cuda_python"

    # Version 13.x releases
    version("13.1.0", sha256="63cc2823bb73bfe1e7e697457364d626f8e7705d6c3dc93a7d120dd788e2a93e", preferred=True)
    version("13.0.0", sha256="606bb3202392eb1014c82023e44858dbdd13a6ad7e4529251a12e72c76c7171f")

    # Version 12.x releases (satisfies cuda-bindings>=12.9.2)
    version("12.9.5", sha256="c7aa5390faad675db7af568bda48607888f3ce987aa9c463f95c5e33f4f04a3b")
    version("12.9.4", sha256="3e95a80d5e1fea864dd55f7600f9e5c9af6e42866ae15206e386338649efea13")
    version("12.9.3", sha256="8390a57c4f030fcd0557e02c3f6dc32e676413ae87f409630fa280ad05c218a7")
    version("12.9.2", sha256="14ed346e848f796929516ebce1e3b33567c4f285abf44aa767ec8e9542ca6a68")

    # Python version requirements
    depends_on("python@3.10:", type=("build", "run"))

    # Build dependencies
    depends_on("py-setuptools@80:", type="build")
    depends_on("py-setuptools-scm@8:+simple", type="build")
    depends_on("py-packaging", type="build")

    # CUDA toolkit - cuda-python works with CUDA 11.x and 12.x
    # Version numbers (12.9.x, 13.x) are package versions, not CUDA requirements
    depends_on("cuda@11.8:", when="@12:", type="build")
    depends_on("cuda@12:", when="@13:", type="build")

    # Variant for optional CUDA toolkit components
    variant("all", default=False, description="Install all optional CUDA toolkit bindings")

    def setup_build_environment(self, env):
        # Set CUDA_HOME for the build process (needed by cuda-bindings)
        if self.spec.satisfies("^cuda"):
            env.set("CUDA_HOME", self.spec["cuda"].prefix)
            env.set("CUDA_PATH", self.spec["cuda"].prefix)
