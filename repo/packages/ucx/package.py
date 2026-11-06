# Copyright 2026 Pawsey Supercomputing Centre
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.ucx.package import Ucx as BuiltinUcx

from spack.package import *


class Ucx(BuiltinUcx):
    """Add CUDA 13 support and Grace Hopper transport fixes to the pinned recipes."""

    version("1.20.1", sha256="545c419a7b5e04643cb8bff5a19b3b5071a8f8f0605f1e8efb36f8f3d7bfb9d3")

    def configure_args(self):
        args = super().configure_args()
        # UCX 1.20 adds device code; the older builtin recipe does not pass
        # cuda_arch through to its new nvcc configuration option.
        if self.spec.satisfies("@1.20: +cuda"):
            cuda_arch = self.spec.variants["cuda_arch"].values
            if cuda_arch != ("none",):
                args.append("--with-nvcc-gencode=" + " ".join(self.cuda_flags(cuda_arch)))
        return args
