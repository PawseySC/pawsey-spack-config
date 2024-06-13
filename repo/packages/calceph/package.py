# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class Calceph(AutotoolsPackage):
    """
    CALCEPH is a library designed to access the binary planetary ephemeris files, such INPOPxx, JPL DExxx and SPICE ephemeris files.
    It provides a C Application Programming Interface (API) and, optionally, Fortran 77/2003, Python 2/3 and octave/Matlab interfaces to be called by the application.
    """

    homepage = "https://www.imcce.fr/inpop/calceph"
    url = "https://www.imcce.fr/content/medias/recherche/equipes/asd/calceph/calceph-3.5.5.tar.gz"

    version("3.5.5", sha256="f7acf529a9267793126d7fdbdf79d4d26ae33274c99d09a9fc9d6191a3c72aca")

    def configure_args(self):
        args = [
                "--with-pic",
                "--enable-shared",
                "--enable-static",
                "--enable-fortran",
                "--enable-thread"
        ]
        return args
