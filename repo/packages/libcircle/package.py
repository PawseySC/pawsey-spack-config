# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

import os

from spack_repo.builtin.packages.libcircle.package import Libcircle as BuiltinLibcircle

from spack.package import *


class Libcircle(BuiltinLibcircle):
    """Avoid transitive linking through relocated external Open MPI archives."""

    @run_after("configure")
    def link_external_openmpi_directly(self):
        mpi = self.spec["mpi"]
        if not (
            self.spec.satisfies("@0.3.0 platform=linux")
            and mpi.name == "openmpi"
            and mpi.external
        ):
            return

        mpi_library = next(
            (library for library in mpi.libs if os.path.basename(library) == "libmpi.so"),
            None,
        )
        if mpi_library is None:
            raise InstallError("Cannot locate the external Open MPI shared library libmpi.so")

        # Libtool expands -lmpi through HPC-X's libmpi.la, adding private build
        # dependencies such as -ludev. Pass the shared library directly to the
        # linker; older Libtool versions can drop a bare .so argument.
        # The shared object's runtime dependencies remain intact.
        filter_file(
            r"^(MPI_CLDFLAGS[ \t]*=.*?)(?<!\S)-lmpi(?=\s|$)",
            r"\1-Wl," + mpi_library,
            join_path(self.stage.source_path, "Makefile"),
        )
