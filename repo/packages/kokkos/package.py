# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack_repo.builtin.packages.kokkos.package import Kokkos as BuiltinKokkos

from spack.package import *


class Kokkos(BuiltinKokkos):
    """Kokkos with the CUDA 13 compatible release used on Setonix-Q."""

    # Keep the builtin versions and build logic used by the Setonix CPU/ROCm
    # stacks. Q needs the last 4.x release for its HPX TPL options and the
    # nvcc_wrapper sm_80 default, which remains supported by CUDA 13.
    version("4.7.04", sha256="4213b248c39e112299fa94ee08817e51126fc02996ed6e2ab56aec4cdb80ee1f")
    depends_on("kokkos-nvcc-wrapper@4.7.04", when="@4.7.04+wrapper")
