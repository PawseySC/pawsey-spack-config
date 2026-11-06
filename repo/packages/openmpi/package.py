# Copyright 2026 Pawsey Supercomputing Centre
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.openmpi.package import Openmpi as BuiltinOpenmpi

from spack.package import *


class Openmpi(BuiltinOpenmpi):
    """Most recent stable Open MPI release at time of commit."""
    # https://www.open-mpi.org/software/ompi/v5.0/
    version("5.0.11", sha256="e668a3c4acd50c41dc204c8a6dd98a611e0f26af89cf677577fa9be8a2698003")
