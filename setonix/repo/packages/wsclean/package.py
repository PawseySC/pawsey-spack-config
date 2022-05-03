# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *


class Wsclean(CMakePackage):
    """
    WSClean (w-stacking clean) is a fast generic widefield imager. It uses the w-stacking algorithm 
    and can make use of the w-snapshot algorithm. As of Feb 2014, it is 2-12 times faster than CASA's 
    w-projection, depending on the array configuration. It supports full-sky imaging and proper beam 
    correction for homogeneous dipole arrays such as the MWA.
    WSClean allows Hogbom and Cotton-Schwab cleaning and has wideband, multiscale, compressed 
    sensing and joined-polarization deconvolution modes. All operations are performed on the CPU.
    """

    homepage = "https://wsclean.readthedocs.io/en/latest/"
    url      = "https://sourceforge.net/projects/wsclean/files/wsclean-2.10/wsclean-2.10.1.tar.bz2"

    version('2.10.1', sha256='778edc1e73ce346a62063eef570054c268727a0fab47b999549d678a8b26ee1e')
    version('2.9', sha256='d3e6d2de3cb923f5fa37638977c58bbe56a9db79ac2523ef0d0dbb3c1afe065d')

    depends_on('chgcentre', type='build')
    depends_on('casacore')
    depends_on('fftw-api@3')
    depends_on('idg')
    depends_on('gsl')
    depends_on('cfitsio')

    def url_for_version(self, version):
        version_numbers = str(version).split('.')
        return ("https://sourceforge.net/projects/wsclean/files/wsclean-{0}/wsclean-{1}.tar.bz2".format(version_numbers[0]+'.'+version_numbers[1], version))

