# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Contribute back the recipe
from spack.package import *


class Idg(CMakePackage, CudaPackage):
    """
    Image Domain Gridding (IDG) is a fast method for convolutional resampling (gridding/degridding) 
    of radio astronomical data (visibilities). Direction-dependent effects (DDEs) 
    or A-tems can be applied in the gridding process.
    """

    homepage = "https://www.astron.nl/citt/IDG/"
    git      = "https://gitlab.com/astron-idg/idg.git"

    version("1.2.0", tag="1.2.0")
    version("1.1.0", tag="1.1.0")
    version("1.0.0", tag="1.0.0")
    version("0.7", tag="0.7")

    depends_on('boost')
    depends_on('fftw-api@3')
    depends_on('blas')


    def cmake_args(self):
        args = []
        if '+cuda' in self.spec:
            args.append("-DBUILD_LIB_CUDA=ON")
            args.append(f"-DCUDA_ROOT_DIR={self.spec['cuda'].prefix}")
        return args
