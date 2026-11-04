# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.py_cuda_bindings.package import PyCudaBindings as BuiltinPyCudaBindings

from spack.package import *


class PyCudaBindings(BuiltinPyCudaBindings):
    """CUDA Python bindings for the CUDA 13.0 and 13.1 software stacks."""

    license("LicenseRef-NVIDIA-SOFTWARE-LICENSE")

    version(
        "13.1.1",
        sha256="67d3664c91687c2799b9531ca94fb41908857b06b045cdf51343f4176fae63ac",
        url="https://github.com/NVIDIA/cuda-python/archive/refs/tags/v13.1.1.tar.gz",
    )
    version(
        "13.0.3",
        sha256="4885b7898ba30735cdf8a07b52496ecfe2b8f7d119245f3ced190f9ad445ffd4",
        url="https://github.com/NVIDIA/cuda-python/archive/refs/tags/v13.0.3.tar.gz",
        preferred=True,
    )

    depends_on("c", type="build")
    depends_on("cxx", type="build")
    with when("@13.0.3"):
        depends_on("cuda@13.0", type=("build", "link", "run"))
        depends_on("py-cython@3.1:3.1", type="build")
        depends_on("py-setuptools@77:", type="build")
        depends_on("py-pyclibrary@0.1.7:", type=("build", "run"))
        depends_on("py-cuda-pathfinder@1.1:1", type="run")

    with when("@13.1.1"):
        depends_on("cuda@13.1", type=("build", "link", "run"))
        depends_on("python@3.10:", type=("build", "run"))
        depends_on("py-cython@3.2:3.2", type="build")
        depends_on("py-setuptools@77:", type="build")
        depends_on("py-pyclibrary@0.1.7:", type=("build", "run"))
        depends_on("py-cuda-pathfinder@1.1:1", type="run")

    variant("cufile", default=False, when="@13.0.3,13.1.1", description="Build cuFile bindings")

    @when("@13.0.3,13.1.1 ~cufile")
    def patch(self):
        setup = join_path(self.stage.source_path, "cuda_bindings", "setup.py")
        # Exclude both the public and generated internal cuFile extensions.
        filter_file(r'^if sys\.platform == "win32":', "if True:", setup)
        filter_file(
            "dst_files = rename_architecture_specific_files()",
            'dst_files = [f for f in rename_architecture_specific_files() if "cufile" not in f]',
            setup,
            string=True,
        )

    def setup_build_environment(self, env):
        super().setup_build_environment(env)
        env.set("CUDA_HOME", self.spec["cuda"].prefix)
        env.set("CUDA_PATH", self.spec["cuda"].prefix)
