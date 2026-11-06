# Copyright 2026 Pawsey Supercomputing Centre
# SPDX-License-Identifier: BSD-3-Clause

import os

from spack.package import *


class SlurmPmi2(Package):
    """Slurm's PMI2 header paired with its installed client library."""

    homepage = "https://slurm.schedmd.com/mpi_guide.html"
    url = "https://raw.githubusercontent.com/SchedMD/slurm/slurm-25-11-8-1/contribs/pmi2/pmi2.h"

    version(
        "25.11.8",
        sha256="cf92aa702690ec6870374b18f5612a78db3de46e77a6268aa1e8b52fabf0c184",
        url=url,
        expand=False,
    )
    depends_on("slurm@25.11.8", type=("build", "link", "run"))

    def install(self, spec, prefix):
        # Use Slurm's ABI 0 library, rather than PMIx's libpmi2.so.1 shim.
        for libdir in (spec["slurm"].prefix.lib64, spec["slurm"].prefix.lib):
            library = join_path(libdir, "libpmi2.so.0.0.0")
            if os.path.isfile(library):
                break
        else:
            raise InstallError("Slurm's libpmi2.so.0.0.0 is missing from its external prefix")

        mkdirp(prefix.include.slurm, prefix.lib)
        install(self.stage.archive_file, join_path(prefix.include.slurm, "pmi2.h"))
        for name in ("libpmi2.so", "libpmi2.so.0"):
            symlink(library, join_path(prefix.lib, name))
