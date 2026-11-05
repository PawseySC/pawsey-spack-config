# Copyright Spack Project Developers. See COPYRIGHT file for details.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class Cusparselt(Package):
    """NVIDIA cuSPARSELt for the CUDA 13 Linux SBSA stacks on GH200."""

    homepage = "https://docs.nvidia.com/cuda/cusparselt/"
    url = "https://developer.download.nvidia.com/compute/cusparselt/redist/libcusparse_lt/linux-sbsa/libcusparse_lt-linux-sbsa-0.8.1.1_cuda13-archive.tar.xz"
    version("0.8.1.1", sha256="d3ce9fb25961540291c6dc6c7292a1ea7cb886590bf896fdc2564cb2a261a3de")
    license("LicenseRef-cuSPARSELt")
    depends_on("cuda@13", type=("build", "link", "run"))

    def install(self, spec, prefix):
        if not spec.satisfies("platform=linux target=aarch64:"):
            raise InstallError("This cuSPARSELt binary requires Linux SBSA")
        install_tree("include", prefix.include)
        install_tree("lib", prefix.lib)
