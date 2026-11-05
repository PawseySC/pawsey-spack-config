# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipsparselt(HipMathPackage):
    """HIP structured sparse matrix operations backed by NVIDIA cuSPARSELt."""

    license("MIT")
    depends_on("cusparselt@0.8.1.1")
    depends_on("python@3.6:", type="build")
    depends_on("hipsparse@7.2.4 +cuda ~rocm", when="@7.2.4")
    depends_on("hipsparse@10.1.0 +cuda ~rocm", when="@10.1.0")
    patch("fix-cuda-cmake.patch")

    @property
    def git_sparse_paths(self):
        # Exclude the AMD Tensile kernel corpus from the CUDA checkout.
        return [self.root_cmakelists_dir + "/" + path for path in
                ("cmake", "library/include", "library/src/include", "library/src/nvcc_detail")] + [
            "shared/ctest"
        ]

    def cmake_args(self):
        return super().cmake_args() + [
            self.define("HIPSPARSELT_ENABLE_CUDA", True),
            self.define("HIPSPARSELT_ENABLE_HIP", False),
            self.define("HIPSPARSELT_ENABLE_CLIENT", False),
            self.define("HIPSPARSELT_BUILD_TESTING", False),
            self.define("HIPSPARSELT_ENABLE_MARKER", False),
            self.define("HIPSPARSELT_ENABLE_OPENMP", False),
        ]
