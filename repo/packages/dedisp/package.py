# Copyright 2013-2023 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

# ----------------------------------------------------------------------------
# If you submit this package back to Spack as a pull request,
# please first remove this boilerplate and all FIXME comments.
#
# This is a template package file for Spack.  We've put "FIXME"
# next to all the things you'll want to change. Once you've handled
# them, you can save this file and test your package like this:
#
#     spack install dedisp
#
# You can edit this file again by typing:
#
#     spack edit dedisp
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

from spack.package import *


class Dedisp(AutotoolsPackage, SourceforgePackage):
    """FIXME: Put a proper description of your package here."""

    homepage = "https://www.example.com"
    git = "https://git.code.sf.net/p/dspsr/code"

    maintainers("dipietrantonio")

    version("2024-06-13", commit="e15cb3")

    depends_on("autoconf", type="build")
    depends_on("automake", type="build")
    depends_on("libtool", type="build")
    depends_on("m4", type="build")
    depends_on("swig")

    def autoreconf(self, spec, prefix):
        autoreconf("--install", "--verbose", "--force") 

    def configure_args(self):
        # FIXME: Add arguments other than --prefix
        # FIXME: If not needed delete this function
        args = []
        return args
