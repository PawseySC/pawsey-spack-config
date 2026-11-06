# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

import platform

from spack_repo.builtin.packages.nvhpc.package import Nvhpc as BuiltinNvhpc

from spack.package import *


_installers = {
    "Linux-aarch64": (
        "31e96aa7746e2a03b08e43bdc8b388c30955dd8bcbc756594b3f9955cbc3419e",
        "https://developer.download.nvidia.com/hpc-sdk/26.1/nvhpc_2026_261_Linux_aarch64_cuda_multi.tar.gz",
    ),
    "Linux-x86_64": (
        "16400a28e21402dddf0b1699aa17df53f1017f738355d5fa0c273a35d9f0df06",
        "https://developer.download.nvidia.com/hpc-sdk/26.1/nvhpc_2026_261_Linux_x86_64_cuda_multi.tar.gz",
    ),
}


class Nvhpc(BuiltinNvhpc):
    """Add the NVIDIA HPC SDK 26.1 release, including its CUDA 13.1 toolkit."""

    _installer = _installers.get(f"{platform.system()}-{platform.machine()}")
    if _installer:
        version("26.1", sha256=_installer[0], url=_installer[1])
