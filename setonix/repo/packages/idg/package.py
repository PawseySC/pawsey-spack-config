# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *


class Idg(CMakePackage):
    """
    Image Domain Gridding (IDG) is a fast method for convolutional resampling (gridding/degridding) 
    of radio astronomical data (visibilities). Direction-dependent effects (DDEs) 
    or A-tems can be applied in the gridding process.
    """

    homepage = "https://www.astron.nl/citt/IDG/"
    url      = "https://git.astron.nl/RD/idg/-/archive/1.0.0/idg-1.0.0.tar.gz"

    version('1.0.0', sha256='b5194e42850d25a34bab8d176986b6c312bbded9a39035e23faad1bc72455263')

    depends_on('boost')
    depends_on('fftw-api@3')

    def url_for_version(self, version):
        return ("https://git.astron.nl/RD/idg/-/archive/{0}/idg-{0}.tar.gz".format(version))

    # def cmake_args(self):
    #     args = []
    #     spec = self.spec
    #     args.append(self.define_from_variant('ENABLE_SHARED', 'shared'))

    #     return args

