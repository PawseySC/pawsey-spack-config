# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class PyNvmathPython(PythonPackage):
    """NVIDIA Math Python libraries - high-performance mathematical computing on GPUs."""

    homepage = "https://developer.nvidia.com/nvmath-python"
    pypi = "nvmath-python/nvmath_python-0.6.0.tar.gz"
    git = "https://github.com/NVIDIA/nvmath-python.git"

    maintainers("Edric-Matwiejew")

    license("Apache-2.0")

    version("0.6.0", sha256="d6578b8fcb25228c50009914e814cd5d73216841f5b61713a6f58b4ecf0bedad")

    variant("cu12", default=True, description="Enable CUDA 12 support")
    variant("cu13", default=False, description="Enable CUDA 13 support")
    variant("dx", default=False, description="Enable device extensions (cuBLASDx, cuFFTDx)")
    variant("distributed", default=False, description="Enable distributed computing support")
    variant("cpu", default=False, description="Enable CPU fallback support")

    conflicts("+cu12", when="+cu13", msg="Cannot enable both CUDA 12 and CUDA 13 support")

    depends_on("python@3.10:3.13", type=("build", "run"))
    depends_on("py-setuptools@77:", type="build")
    depends_on("py-cython@3.2:", type="build")
    depends_on("py-tomli@2:", type="build", when="^python@:3.10")
    depends_on("py-numpy@1.25:2", type=("build", "run"))
    depends_on("py-cuda-python", type=("build", "run"))
    depends_on("cuda@12:12", when="+cu12", type=("build", "run"))
    depends_on("cuda@13:", when="+cu13", type=("build", "run"))

    depends_on("cublas", type=("build", "run"))
    depends_on("cufft", type=("build", "run"))
    depends_on("curand", type=("build", "run"))
    depends_on("cusolver", type=("build", "run"))
    depends_on("cusparse", type=("build", "run"))
    depends_on("cutensor@2.3.1:", type=("build", "run"))

    # Device extensions dependencies
    with when("+dx"):
        depends_on("py-numba", type=("build", "run"))
        depends_on("py-numba-cuda@0.24:", type=("build", "run"))

    # Distributed dependencies
    with when("+distributed"):
        depends_on("py-mpi4py", type=("build", "run"))
        depends_on("nccl@2.18:", type=("build", "run"))

    # CPU fallback dependencies
    depends_on("mkl", when="+cpu target=x86_64:", type=("build", "run"))

    def setup_build_environment(self, env):
        # Ensure CUDA is available during build
        if self.spec.satisfies("+cu12") or self.spec.satisfies("+cu13"):
            env.set("CUDA_HOME", self.spec["cuda"].prefix)
            env.set("CUDA_PATH", self.spec["cuda"].prefix)
