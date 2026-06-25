# Copyright 2013-2023 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *


class Presto(MesonPackage):
    """
    PRESTO is a large suite of pulsar search and analysis software developed primarily by Scott 
    Ransom mostly from scratch, and released under the GPL (v2). It was primarily designed to 
    efficiently search for binary millisecond pulsars from long observations of globular 
    clusters (although it has since been used in several surveys with short integrations and to 
    process a lot of X-ray data as well). It is written primarily in ANSI C, with many of the 
    recent routines in Python. According to Steve Eikenberry, PRESTO stands for: PulsaR 
    Exploration and Search TOolkit!
    """
    homepage = "http://www.cv.nrao.edu/~sransom/presto"
    git = "https://github.com/scottransom/presto.git"

    maintainers("dipietrantonio")

    license("GPL-2")

    version("5.0.1", tag="v5.0.1")

    depends_on("glib")
    depends_on("fftw-api@3:")
    depends_on("pgplot")
    depends_on("cfitsio")
    depends_on("libpng")
    depends_on("python@3.6:")
 
