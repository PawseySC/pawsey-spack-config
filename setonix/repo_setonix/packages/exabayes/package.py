# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


class Exabayes(AutotoolsPackage):
    """ExaBayes is a software package for Bayesian tree inference. It is
       particularly suitable for large-scale analyses on computer clusters."""

    homepage = "https://cme.h-its.org/exelixis/web/software/exabayes/index.html"
    url      = "https://cme.h-its.org/exelixis/resource/download/software/exabayes-1.5.1.tar.gz"

    version('1.5.1', sha256='f75ce8d5cee4d241cadacd0f5f5612d783b9e9babff2a99c7e0c3819a94bbca9')
    variant('openmpi', default=True, description='Enable openMP parallel support')

    #Spack spec fails if this line is not commented out. 
    #depends_on('openmpi', when='+openmpi')

    variant('mpich', default=False, description='Enable mpich parallel support')
    depends_on('cray-mpich', when='+mpich')

    # ExaBayes manual states the program succesfully compiles with GCC, version
    # 4.6 or greater, and Clang, version 3.2 or greater.
    conflicts('%gcc@:4.5.4')
    conflicts('%clang@:3.1')

    def configure_args(self):
        args = []
        if '+mpich' in self.spec:
            args.append('--enable-mpich')
        else:
            args.append('--disable-mpich')
        return args

    def configure_args(self):
        args = []
        if '+openmpi' in self.spec:
            args.append('--enable-openmpi')
        else:
            args.append('--disable-openmpi')
        return args
