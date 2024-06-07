# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Contribute recipe
from spack.package import *


class Everybeam(CMakePackage):
    """
    The EveryBeam library is a library that provides the antenna response pattern for several instruments, 
    such as LOFAR (and LOBES), SKA (OSKAR), MWA, JVLA, etc.
    """

    homepage = "https://wsclean.readthedocs.io/en/latest/"
    git      = "https://git.astron.nl/RD/EveryBeam.git"
    
    version('0.6.0', tag='v0.6.0', submodules=True)
    version('0.5.8', tag='v0.5.8', submodules=True)
    version('0.5.2', tag='v0.5.2', submodules=True)
    version('0.4.0', tag='v0.4.0', submodules=True)
    version('0.3.1', tag='v0.3.1', submodules=True)
    version('0.3.0', tag='v0.3.0', submodules=True)
    version('0.2.0', tag='v0.2.0', submodules=True)

    variant('python', default=False, description='Add python support')
    variant('tests', default=False, description='Build tests')
    variant('lobes', default=False, description='Download and install the LOBEs coefficient files')

    depends_on('casacore')
    depends_on('fftw-api@3')
    depends_on('boost', when="@0.3.1:")
    depends_on('boost +filesystem', when="@:0.3.0")
    depends_on('blas')
    depends_on('lapack')
    depends_on('cfitsio')
    depends_on('hdf5~mpi+cxx+hl api=v110')
    depends_on('doxygen')
    depends_on('py-sphinx')
    depends_on('git')
    depends_on('python')

    patch('cmake.patch', when='@:0.2.0')
    patch('cmake.lobes.patch', when='@0.2.0')
    patch('cmake.hamaker.patch', when='@0.2.0')
    patch('cmake.oskar.patch', when='@0.2.0')

    def cmake_args(self):
        args = []
        spec = self.spec
        args.append(self.define_from_variant('BUILD_WITH_PYTHON', 'python'))
        args.append(self.define_from_variant('BUILD_TESTING', 'tests'))
        args.append(self.define_from_variant('DOWNLOAD_LOBES', 'lobes'))

        return args
