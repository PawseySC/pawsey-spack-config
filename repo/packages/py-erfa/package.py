# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import platform
import subprocess

from spack import *


class PyErfa(PythonPackage):
    """PyERFA is the Python wrapper for the ERFA library (Essential Routines for Fundamental Astronomy),
    a C library containing key algorithms for astronomy, which is based on the SOFA library published by
    the International Astronomical Union (IAU). All C routines are wrapped as Numpy universal functions,
    so that they can be called with scalar or array inputs.
    """

    homepage = "https://pyerfa.readthedocs.io"
    pypi = "pyerfa/pyerfa-2.0.0.1.tar.gz"
    git      = "https://github.com/liberfa/pyerfa.git"

    maintainers = ['Pascal Jahan Elahi']

    version('main', branch='main')
    version('2.0.0.1', sha256='2fd4637ffe2c1e6ede7482c13f583ba7c73119d78bef90175448ce506a0ede30')
    version('1.7.3', sha256='6cf3a645d63e0c575a357797903eac5d2c6591d7cdb89217c8c4d39777cf18cb')

    depends_on('python@3:', type=('build', 'link', 'run'))
    depends_on('py-setuptools@3.2:', type='build')
    depends_on('py-pip', type='build')
    depends_on('py-packaging', type='build')
    depends_on('py-pkgconfig', type='build')
    depends_on('py-numpy@1.13:', type=('build', 'run'))
    #depends_on('py-six', type=('build', 'run'))
    depends_on('erfa')
