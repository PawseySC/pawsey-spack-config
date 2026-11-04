# Copyright 2026 Pawsey Supercomputing Centre
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.openmpi.package import Openmpi as BuiltinOpenmpi

from spack.package import *


class Openmpi(BuiltinOpenmpi):
    """Use the matching PMI2 header alongside Ella's external Slurm library."""

    depends_on("slurm-pmi2@25.11.8", when="@4 +pmi ^slurm@25.11.8")

    def configure_args(self):
        args = super().configure_args()
        if "^slurm-pmi2" in self.spec:
            pmi2 = self.spec["slurm-pmi2"].prefix
            args = [arg for arg in args if not arg.startswith("--with-pmi=")]
            args += [f"--with-pmi={pmi2}", f"--with-pmi-libdir={pmi2.lib}"]
        return args
