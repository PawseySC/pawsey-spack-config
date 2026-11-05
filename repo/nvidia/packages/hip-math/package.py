# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


# Retain ROCm variants for consumers' inactive +rocm dependency constraints.
class HipMathPackage(CMakePackage, CudaPackage, ROCmPackage):
    """Shared sources and NVIDIA build settings for Pawsey's HIP wrappers."""

    homepage = "https://github.com/ROCm/rocm-libraries"
    git = "https://github.com/ROCm/rocm-libraries.git"
    version(
        "10.1.0",
        tag="therock-10.1",
        commit="39d8d60365d2272a5366f76ccb3bfba24b219eaf",
    )
    version(
        "7.2.4",
        tag="rocm-7.2.4",
        commit="dabb6df2b988f8eabed1e2fecefaaf4e818bc7ef",
    )

    variant("cuda", default=True, description="Build the NVIDIA backend")
    conflicts("~cuda", msg="These Pawsey recipes require the NVIDIA backend")
    conflicts("+rocm", msg="These Pawsey recipes require the NVIDIA backend")

    depends_on("c", type="build")
    depends_on("cxx", type="build")
    depends_on("cmake@3.25.2:", type="build")
    depends_on("rocm-cmake@7.0.2", type="build")
    depends_on("python@3.9:", when="@10.1.0", type="build")
    depends_on("hip@7.2.4 +cuda ~rocm", when="@7.2.4", type=("build", "link", "run"))
    depends_on("hip@7.16.0 +cuda ~rocm", when="@10.1.0", type=("build", "link", "run"))

    @property
    def root_cmakelists_dir(self):
        return "projects/" + self.name

    @property
    def git_sparse_paths(self):
        return [self.root_cmakelists_dir, "shared/ctest"]

    def cmake_args(self):
        return [
            self.define("HIP_PLATFORM", "nvidia"),
            self.define("CMAKE_MODULE_PATH", self.spec["hip"].prefix.lib.cmake.hip),
            self.define("CMAKE_INSTALL_LIBDIR", "lib"),
            self.define("BUILD_TESTING", False),
            self.define("BUILD_CLIENTS_TESTS", False),
            self.define("BUILD_CLIENTS_SAMPLES", False),
        ]


class HipMath(BundlePackage):
    """Matching NVIDIA HIP runtime, math wrappers and Fortran interfaces."""

    homepage = "https://github.com/ROCm/rocm-libraries"
    version("7.16.0")
    version("7.2.4")

    for hip_version, math_version in (("7.2.4", "7.2.4"), ("7.16.0", "10.1.0")):
        depends_on(f"hip@{hip_version} +cuda ~rocm", when=f"@{hip_version}", type="run")
        for component in (
            "hipblas-common", "hipblas", "hipfft", "hiprand", "hipsolver",
            "hipsparse", "hipcub", "hipfort", "hipsparselt",
        ):
            depends_on(
                f"{component}@{math_version} +cuda ~rocm",
                when=f"@{hip_version}",
                type="run",
            )
