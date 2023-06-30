# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Differences for the 'healpix-cxx' package
# 6c6
# < from spack.package import *
# ---
# > from spack import *
# 20d19
# <     patch('cfitsio_version_check.patch', when="@3.50:")
# 21a21,29
# >     def patch(self):
# >         spec = self.spec
# >         configure_fix = FileFilter('configure')
# >         # Link libsharp static libs
# >         configure_fix.filter(
# >             r'^SHARP_LIBS=.*$',
# >             'SHARP_LIBS="-L{0} -lsharp -lc_utils -lfftpack -lm"'
# >             .format(spec['libsharp'].prefix.lib)
# >         )
# Contribute patch
from spack.package import *


class HealpixCxx(AutotoolsPackage):
    """Healpix-CXX is a C/C++ library for calculating
    Hierarchical Equal Area isoLatitude Pixelation of a sphere."""

    homepage = "https://healpix.sourceforge.io"
    url      = "https://ayera.dl.sourceforge.net/project/healpix/Healpix_3.50/healpix_cxx-3.50.0.tar.gz"

    version('3.50.0', sha256='6538ee160423e8a0c0f92cf2b2001e1a2afd9567d026a86ff6e2287c1580cb4c')

    depends_on('cfitsio')
    depends_on('libsharp', type='build')
    patch('cfitsio_version_check.patch', when="@3.50:")

