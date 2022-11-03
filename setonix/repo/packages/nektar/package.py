# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *


class Nektar(CMakePackage):
    """Nektar++: Spectral/hp Element Framework"""

    homepage = "https://www.nektar.info/"
    url      = "https://gitlab.nektar.info/nektar/nektar/-/archive/v4.4.1/nektar-v4.4.1.tar.bz2"

    version('5.1.0', sha256='f5fdb729909e4dcd42cb071f06569634fa87fe90384ba0f2f857a9e0e56b6ac5')
    version('5.0.3', sha256='1ef6f8f94f850ae78675bca3f752aa6c9f75401d1d6da4ec25df7fa795b860e9')
    version('5.0.2', sha256='24af60a48dbdf0455149540b35a6a59acd636c47b3150b261899a1a1ca886c0b')
    version('5.0.0', sha256='5c594453fbfaa433f732a55405da9bba27d4a00c32d7b9d7515767925fb4a818')
    version('4.4.1', sha256='71cfd93d848a751ae9ae5e5ba336cee4b4827d4abcd56f6b8dc5c460ed6b738c')

    variant('mpi', default=True, description='Builds with mpi support')
    variant('avx2', default=True, description='Builds with simd avx2 support')
    variant('fftw', default=True, description='Builds with fftw support')
    variant('arpack', default=True, description='Builds with arpack support')
    variant('hdf5', default=True, description='Builds with hdf5 support')
    variant('scotch', default=False,
            description='Builds with scotch partitioning support')
    variant('unit-tests', default=False, description='Builds unit tests')
    variant('regression-tests', default=False, description='Builds regression tests')
    variant('benchmarking-tests', default=False, description='Builds benchmark timing codes')
    variant('python', default=False, description='Builds python bindings')

    # depends_on('cmake@2.8.8:', type='build', when="~hdf5")
    # depends_on('cmake@3.2:', type='build', when="+hdf5")

    depends_on('tinyxml', when='platform=darwin')
    depends_on('mpi', when='+mpi')
    depends_on('blas')
    depends_on('lapack')
    # depends_on('boost@1.57.0 ~atomic ~chrono ~exception +filesystem ~graph +iostreams ~locale ~log ~math ~mpi +multithreaded ~numpy +pic ~program_options ~python ~random +regex ~serialization ~signals +system ~test +thread ~timer ~wave')

    depends_on('fftw@3.0: +mpi', when="+mpi+fftw")
    depends_on('fftw@3.0: ~mpi', when="~mpi+fftw")
    depends_on('arpack-ng +mpi', when="+arpack+mpi")
    depends_on('arpack-ng ~mpi', when="+arpack~mpi")
    depends_on('hdf5 +mpi +hl', when="+mpi+hdf5")
    depends_on('scotch ~mpi ~metis', when="~mpi+scotch")
    depends_on('scotch +mpi ~metis', when="+mpi+scotch")

    conflicts('+hdf5', when='~mpi',
              msg='Nektar hdf5 output is for parallel builds only')

    def cmake_args(self):
        args = []

        def hasfeature(feature):
            return 'ON' if feature in self.spec else 'OFF'

        args.append('-DNEKTAR_USE_FFTW=ON')
        args.append('-DNEKTAR_USE_ARPACK=ON')
        args.append('-DNEKTAR_USE_HDF5=ON')
        args.append('-DNEKTAR_ERROR_ON_WARNINGS=OFF')

        args.append('-DNEKTAR_USE_MPI=%s' % hasfeature('+mpi'))
        # args.append('-DNEKTAR_USE_FFTW=%s' % hasfeature('+fftw'))
        # args.append('-DNEKTAR_USE_ARPACK=%s' % hasfeature('+arpack'))
        # args.append('-DNEKTAR_USE_HDF5=%s' % hasfeature('+hdf5'))
        args.append('-DNEKTAR_USE_SCOTCH=%s' % hasfeature('+scotch'))
        args.append('-DNEKTAR_ENABLE_SIMD_AVX2=%s' % hasfeature('+avx2'))
        args.append('-DNEKTAR_USE_PETSC=OFF')
        args.append('-DNEKTAR_BUILD_UNIT_TESTS=%s' % hasfeature('+unit-tests'))
        args.append('-DNEKTAR_BUILD_TESTS=%s' % hasfeature('+regression-tests'))
        args.append('-DNEKTAR_BUILD_TIMINGS=%s' % hasfeature('+benchmarking-tests'))
        args.append('-DNEKTAR_BUILD_PYTHON=%s' % hasfeature('+python'))

        return args
