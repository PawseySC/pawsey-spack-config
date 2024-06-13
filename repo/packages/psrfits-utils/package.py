# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

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

