# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
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
#     spack install psrfits-utils
#
# You can edit this file again by typing:
#
#     spack edit psrfits-utils
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

from spack.package import *
import os

class PsrfitsUtils(AutotoolsPackage):
    """psrfits_utils is a lightweight library for processing PSRFITS pulsar data files."""

    homepage = "https://github.com/scottransom/psrfits_utils"
    git = "https://github.com/scottransom/psrfits_utils"

    version("2023-10-08", commit="284fd0ca259e2201d80a4bf3407a0bef127e77cf")

    depends_on("mpi")
    depends_on("cfitsio")
    depends_on("libtool", type="build")

    # Run the necessary 'prepare' command before configuring
    @run_before("autoreconf")
    def prepare(self):
        os.system("./prepare")

