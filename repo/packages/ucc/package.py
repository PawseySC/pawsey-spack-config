# Copyright 2026 Pawsey Supercomputing Centre
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.ucc.package import Ucc as BuiltinUcc

from spack.package import *


class Ucc(BuiltinUcc):
    """Pass CUDA architecture flags without shell quotes in configure's argv."""

    def configure_args(self):
        args = super().configure_args()
        prefix = "--with-nvcc-gencode="
        for index, arg in enumerate(args):
            if arg.startswith(prefix):
                flags = arg[len(prefix) :]
                # configure preserves literal quotes in NVCC_ARCH. They would
                # collapse all architecture options into one nvcc argument.
                if flags.startswith("'") and flags.endswith("'"):
                    args[index] = prefix + flags[1:-1]
        return args
