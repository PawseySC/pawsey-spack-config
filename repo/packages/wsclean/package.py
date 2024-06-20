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
    homepage = "https://gitlab.com/aroffringa/wsclean"

    maintainers = ['dipietrantonio']

    version('3.4', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.4', submodules=True)
    version('3.3', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.3', submodules=True)
    version('3.2', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.2', submodules=True)
    version('3.1', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.1', submodules=True)
    version('3.0', git='https://gitlab.com/aroffringa/wsclean.git', tag='v3.0', submodules=True)
    version('2.10.1', git='https://gitlab.com/aroffringa/wsclean.git', tag='v2.10.1', submodules=True)
    version('2.9', git='https://gitlab.com/aroffringa/wsclean.git', tag='wsclean2.9', submodules=True)

    variant('idg', default=False, description='To enable Image Domain Gridder (a fast GPU-enabled gridder)')
    variant('everybeam', default=False, when="@3:", description='To apply primary beams for version >=3')
    variant('mpi', default=False,when="@3:", description='To enable distributed mode')

    depends_on('casacore@3.2.1:')
    depends_on('fftw-api@3')
    depends_on('hdf5@1.10.7: +cxx ~mpi api=v110')
    depends_on('gsl@2.6:')
    depends_on('cfitsio@3.48:')
    depends_on('boost@1.80.0: +date_time +filesystem +system +test +program_options')
    depends_on('idg@0.8.1', when='@3.0 +idg')
    depends_on('idg@1.0.0', when='@3.1: +idg')
    depends_on('everybeam@0.2.0', when='@3.0 +everybeam')
    depends_on('everybeam@0.3.1', when='@3.1 +everybeam')
    depends_on('everybeam@0.4.0', when='@3.2 +everybeam')
    depends_on('everybeam@0.4.0', when='@3.3 +everybeam')
    depends_on('everybeam@0.5.2:0.5.8', when='@3.4 +everybeam')
    depends_on('mpi', when='+mpi')
    depends_on('blas', when='@3.0:')
    depends_on('doxygen', when='@3.0:')
    depends_on('python', when='@3.0:')
    patch("wsclean_2.10.1.patch", when="@2.10.1")
    patch('mpi1.patch', when='@3.0:')
    patch('mpi2.patch', when='@3.0:')

    @run_before("cmake")
    def change_source_dir(self):
        if self.spec.version == Version("2.9"):
            self.__class__.root_cmakelists_dir = "wsclean"


    def cmake_args(self):
        args = [
            f"-DHDF5_LIBRARIES={self.spec['hdf5'].prefix.lib}/libhdf5_cpp.so"
        ]
        args.append(self.define_from_variant('USE_MPI', 'mpi'))
        return args
