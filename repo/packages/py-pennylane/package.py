# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for a combined PennyLane + Lightning qubit/GPU/tensor
# build on setonix-q.

import glob
import shutil

import spack.util.environment
from spack.package import *


class PyPennylane(PythonPackage, CudaPackage):
    """PennyLane with locally built Lightning backends."""

    homepage = "https://pennylane.ai/"
    url = "https://github.com/PennyLaneAI/pennylane-lightning/archive/refs/tags/v0.45.0.tar.gz"

    license("Apache-2.0")

    version("0.45.0", sha256="07ae6b465d8e57f61fb4dc8649c4ba3fc6d43bde4487937cb77075115a7b69d9")

    resource(
        name="pennylane-wheel",
        url="https://files.pythonhosted.org/packages/2a/66/4f30c4b25980d9616848d69a98016f7fbbb74f74d74ae8f04792df5192fd/pennylane-0.45.0-py3-none-any.whl",
        sha256="763ca3520de74b05c9e9dc4b5bc3e4d7f0a05697308a0a01da35e2106ab4ddf6",
        expand=False,
        placement={"pennylane-0.45.0-py3-none-any.whl": "pennylane-0.45.0-py3-none-any.whl"},
        when="@0.45.0",
    )

    variant("gpu", default=True, description="Build the Lightning-GPU backend")
    variant("tensor", default=True, description="Build the Lightning-Tensor backend")
    variant("mpi", default=True, description="Enable MPI support for Lightning-GPU")

    conflicts("~cuda", when="+gpu", msg="Lightning-GPU requires CUDA")
    conflicts("~cuda", when="+tensor", msg="Lightning-Tensor requires CUDA")
    conflicts("+mpi", when="~gpu", msg="MPI support is only used by Lightning-GPU")
    conflicts("cuda_arch=none", when="+cuda")

    depends_on("c", type="build")
    depends_on("cxx", type="build")
    depends_on("blas", type=("build", "link", "run"))

    depends_on("python@3.11:", type=("build", "run"))
    depends_on("py-pip", type="build")
    depends_on("py-build", type="build")
    depends_on("py-setuptools@75.8.1:", type="build")
    depends_on("py-wheel", type="build")
    depends_on("py-tomli", type="build")
    depends_on("py-tomlkit", type=("build", "run"))
    depends_on("cmake", type="build")
    depends_on("ninja", type="build")

    depends_on("py-numpy@2.0:", type=("build", "run"))
    depends_on("py-scipy", type=("build", "run"))
    depends_on("py-networkx", type=("build", "run"))
    depends_on("py-rustworkx@0.14:", type=("build", "run"))
    depends_on("py-autograd", type=("build", "run"))
    depends_on("py-appdirs", type=("build", "run"))
    depends_on("py-autoray@0.8.4", type=("build", "run"))
    depends_on("py-cachetools", type=("build", "run"))
    depends_on("py-requests", type=("build", "run"))
    depends_on("py-typing-extensions", type=("build", "run"))
    depends_on("py-packaging", type=("build", "run"))
    depends_on("py-diastatic-malt", type=("build", "run"))
    depends_on("py-gast", type=("build", "run"))

    depends_on("cuda@13.0.0:13.0.999", when="+cuda", type=("build", "link", "run"))
    depends_on("cuquantum@25.11.1:", when="+cuda", type=("build", "link", "run"))
    depends_on("cutensor@2.4.1.4:", when="+tensor", type=("build", "link", "run"))
    depends_on("mpi", when="+mpi", type=("build", "link", "run"))
    depends_on("py-mpi4py+gtl", when="+mpi", type=("build", "run"))

    def _cuda_architectures(self):
        archs = self.spec.variants["cuda_arch"].value
        if archs == "none":
            return None
        return ";".join(str(a) for a in archs)

    def _gtl_lib_path(self):
        if "py-mpi4py" not in self.spec:
            return None

        mpi4py = self.spec["py-mpi4py"]
        if "+gtl" not in mpi4py:
            return None

        gtl_path = mpi4py.variants["gtl_lib_path"].value
        if gtl_path in (None, "", "auto"):
            return None
        return gtl_path

    def _setup_cuda_environment(self, env):
        if "+cuda" not in self.spec:
            return

        env.set("PL_CUDA_VERSION", "13")

        if "cuquantum" in self.spec:
            env.set("CUQUANTUM_SDK", self.spec["cuquantum"].prefix)

    def _setup_mpi_environment(self, env):
        if "+mpi" not in self.spec:
            return

        env.set("MPICC", self.spec["mpi"].mpicc)
        env.set("MPICXX", self.spec["mpi"].mpicxx)
        env.set("MPICH_GPU_SUPPORT_ENABLED", "1")
        env.set("MPICH_GPU_IPC_ENABLED", "0")

        gtl_path = self._gtl_lib_path()
        if gtl_path:
            env.prepend_path("LD_LIBRARY_PATH", gtl_path)
            env.prepend_path("CRAY_LD_LIBRARY_PATH", gtl_path)
            env.append_flags("LDFLAGS", "-L{0} -lmpi_gtl_cuda -Wl,-rpath,{0}".format(gtl_path))

    def setup_build_environment(self, env):
        self._setup_cuda_environment(env)
        self._setup_mpi_environment(env)

    def setup_run_environment(self, env):
        self._setup_cuda_environment(env)
        self._setup_mpi_environment(env)

    def install(self, spec, prefix):
        wheelhouse = join_path(self.stage.source_path, "spack-wheelhouse")
        mkdirp(wheelhouse)

        pennylane_wheel = join_path(self.stage.source_path, "pennylane-{0}-py3-none-any.whl".format(spec.version))
        pip("install", "--no-deps", "--prefix={0}".format(prefix), pennylane_wheel)

        pyproject = join_path(self.stage.source_path, "pyproject.toml")
        pyproject_spack = join_path(self.stage.source_path, "pyproject.toml.spack")
        shutil.copyfile(pyproject, pyproject_spack)

        self._build_lightning_backend(
            "lightning_qubit",
            "-DENABLE_OPENMP=ON -DENABLE_BLAS=ON -DLQ_ENABLE_KERNEL_OMP=ON",
            wheelhouse,
            pyproject_spack,
        )

        if "+gpu" in spec:
            args = ["-DPL_CUDA_VERSION=13", "-DCMAKE_CUDA_ARCHITECTURES={0}".format(self._cuda_architectures())]
            if "+mpi" in spec:
                args.append("-DENABLE_MPI=ON")
            self._build_lightning_backend("lightning_gpu", " ".join(args), wheelhouse, pyproject_spack)

        if "+tensor" in spec:
            args = ["-DPL_CUDA_VERSION=13", "-DCMAKE_CUDA_ARCHITECTURES={0}".format(self._cuda_architectures())]
            self._build_lightning_backend("lightning_tensor", " ".join(args), wheelhouse, pyproject_spack)

        for wheel in sorted(glob.glob(join_path(wheelhouse, "*.whl"))):
            pip("install", "--no-deps", "--prefix={0}".format(prefix), wheel)

    def _build_lightning_backend(self, backend, cmake_args, wheelhouse, pyproject_spack):
        shutil.copyfile(pyproject_spack, "pyproject.toml")
        shutil.rmtree("build", ignore_errors=True)
        shutil.rmtree("dist", ignore_errors=True)
        for egg_info in glob.glob("*.egg-info"):
            shutil.rmtree(egg_info, ignore_errors=True)

        with spack.util.environment.set_env(PL_BACKEND=backend, CMAKE_ARGS=cmake_args):
            python("scripts/configure_pyproject_toml.py")
            python("-m", "build", "--wheel", "--no-isolation", "--skip-dependency-check")

        wheels = glob.glob(join_path("dist", "*.whl"))
        if not wheels:
            raise InstallError("No wheel was produced for {0}".format(backend))

        for wheel in wheels:
            install(wheel, wheelhouse)
