# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipcub(HipMathPackage):
    """HIP parallel primitives backed by NVIDIA CUB."""

    # LICENSE.txt covers BSD code; headers such as tuple.hpp carry MIT notices.
    license("BSD-3-Clause AND MIT")
    depends_on("cccl@2.8.2", type=("build", "link", "run"))

    def cmake_args(self):
        args = super().cmake_args() + [
            self.define("HIP_COMPILER", "nvcc"),
            self.define("BUILD_TEST", False),
            self.define("BUILD_BENCHMARK", False),
            self.define("BUILD_EXAMPLE", False),
            self.define("CCCL_DIR", self.spec["cccl"].prefix.lib.cmake.cccl),
        ]
        if self.spec.variants["cuda_arch"].value != ("none",):
            args.append(self.define("CMAKE_CUDA_ARCHITECTURES", self.spec.variants["cuda_arch"].value))
        return args

    def setup_run_environment(self, env):
        env.prepend_path("CPATH", self.spec["cccl"].prefix.include)
