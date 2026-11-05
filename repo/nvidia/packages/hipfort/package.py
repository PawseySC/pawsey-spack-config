# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *
from spack.pkg.pawsey_nvidia.hip_math import HipMathPackage


class Hipfort(HipMathPackage):
    """Fortran interfaces to HIP and NVIDIA CUDA libraries."""

    license("MIT")
    homepage = "https://github.com/ROCm/hipfort"
    git = None
    version(
        "7.2.4",
        url="https://github.com/ROCm/hipfort/archive/refs/tags/rocm-7.2.4.tar.gz",
        sha256="b976a421383c9f4b0d0cd48c8070a6b683e1ded0b26ed95bee0c1e376d949c47",
    )
    version(
        "10.1.0",
        url="https://github.com/ROCm/hipfort/archive/refs/tags/rocm-10.1.0.tar.gz",
        sha256="13ab80ea91183f36d37c16ca21a5bf685bec7bfa9912212778e5558ca8a86310",
    )
    depends_on("fortran", type="build")
    root_cmakelists_dir = "."

    @run_before("cmake")
    def sbsa_hipfc(self):
        if self.spec.satisfies("@7.2.4 target=aarch64:"):
            filter_file("targets/x86_64-linux", "targets/sbsa-linux", "bin/hipfc", string=True)

    def cmake_args(self):
        args = super().cmake_args() + [
            self.define("HIPFORT_COMPILER", self.compiler.fc),
            self.define("HIPFORT_BUILD_AMDGCN", False),
            self.define("HIPFORT_BUILD_NVPTX", True),
            self.define("HIPFORT_MULTITOOLCHAIN_LAYOUT", False),
        ]
        if self.spec.satisfies("%gcc"):
            args.append(self.define("CMAKE_Fortran_FLAGS", "-ffunction-sections -fdata-sections"))
        return args

    def setup_run_environment(self, env):
        env.prepend_path("CPATH", self.prefix.include.hipfort.nvptx)
