# Copyright 2013-2023 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


from spack.package import *


class Vdifio(AutotoolsPackage):
    """
    Simple library for parsing VLBI Data Interchange Format (VDIF) packets.
    """
    git = "https://github.com/demorest/vdifio.git"

    maintainers("dipietrantonio")
    license("GPL-2")

    version("master", branch="master")

    depends_on("autoconf", type="build")
    depends_on("automake", type="build")
    depends_on("libtool", type="build")
    depends_on("m4", type="build")

    def autoreconf(self, spec, prefix):
        autoreconf("--install", "--verbose", "--force")

