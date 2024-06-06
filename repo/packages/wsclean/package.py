# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
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
#     spack install cotter
#
# You can edit this file again by typing:
#
#     spack edit cotter
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

from spack import *


class Wsclean(CMakePackage):
    """FIXME: Put a proper description of your package here."""

    homepage = "https://gitlab.com/aroffringa/wsclean"

    maintainers = ['dipietrantonio']

    version('3.4', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.4', submodules=True)
    version('2.10.1', git='https://gitlab.com/aroffringa/wsclean.git', tag='v2.10.1', submodules=True)
    version('2.9', git='https://gitlab.com/aroffringa/wsclean.git', tag='wsclean2.9', submodules=True)

    depends_on('casacore@3.2.1:')
    depends_on('fftw@3.3.8:')
    depends_on('hdf5@1.10.7 +cxx ~mpi api=v110')
    depends_on('gsl@2.6:')
    depends_on('cfitsio')
    depends_on('boost@1.80.0 +date_time +filesystem +system +test +program_options')
    patch("wsclean_2.10.1.patch", when="@2.10.1")

    @run_before("cmake")
    def change_source_dir(self):
        if self.spec.version == Version("2.9"):
            self.__class__.root_cmakelists_dir = "wsclean"


    def cmake_args(self):
        args = [
            f"-DHDF5_LIBRARIES={self.spec['hdf5'].prefix.lib}/libhdf5_cpp.so"
        ]
        return args
