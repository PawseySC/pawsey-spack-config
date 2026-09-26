# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack_repo.builtin.build_systems.autotools import AutotoolsPackage
from spack_repo.builtin.build_systems.sourceforge import SourceforgePackage

from spack.package import *


class Mcpp(AutotoolsPackage, SourceforgePackage):
    """MCPP is an alternative C/C++ preprocessor with the highest
    conformance."""

    homepage = "https://sourceforge.net/projects/mcpp/"
    sourceforge_mirror_path = "mcpp/mcpp/V.2.7.2/mcpp-2.7.2.tar.gz"
    git = "https://github.com/jbrandwood/mcpp.git"

    # Versions from `git describe --tags`
    version("2.7.2-25-g619046f", commit="619046fa0debac3f86ff173098aeb59b8f051d19")
    version("2.7.2", sha256="3b9b4421888519876c4fc68ade324a3bbd81ceeb7092ecdbbc2055099fcb8864")

    depends_on("c", type="build")

    def patch(self):
        # GCC 14 no longer accepts this chained assignment because
        # args and loc_args have different pointer types.
        if self.spec.satisfies("%gcc@14:"):
            filter_file(
                "m_inf->args = m_inf->loc_args = NULL;",
                "m_inf->args = NULL;\n        m_inf->loc_args = NULL;",
                "src/expand.c",
                string=True,
            )

            # Expose the POSIX declaration of readlink().
            filter_file(
                "#define _POSIX_C_SOURCE     1",
                "#define _POSIX_C_SOURCE     200112L",
                "src/configed.H",
                string=True,
            )

    def configure_args(self):
        config_args = ["--enable-mcpplib", "--disable-static"]
        return config_args
