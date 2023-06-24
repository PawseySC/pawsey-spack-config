# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Differences for the 'py-hatchet' package
# 1c1
# < # Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# ---
# > # Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# 6c6
# < from spack.package import *
# ---
# > from spack import *
# 14,15c14,15
# <     url = "https://files.pythonhosted.org/packages/be/75/904c27e3d96d73d5743257caaf820564b0ac3be3497ec2765200ed5241f9/hatchet-1.3.1.tar.gz"
# <     tags = ["radiuss"]
# ---
# >     url      = "https://github.com/hatchet/hatchet/archive/v1.0.0.tar.gz"
# >     tags     = ['radiuss']
# 19,35c19,32
# <     version("1.3.1", sha256="17b36abd4bc8c6d5fed452267634170159062ca3c2534199b1c8378f2f3f1f28")
# <     version("1.3.0", sha256="d77d071fc37863fdc9abc3fd9ea1088904cd98c6980a014a31e44595d2deac5e")
# <     version("1.2.0", sha256="1d5f80abfa69d1a379dff7263908c5c915023f18f26d50b639556e2f43ac755e")
# <     version("1.1.0", sha256="71bfa2881ef295294e5b4493acb8cce98d14c354e9ae59b42fb56a76d8ec7056")
# <     version("1.0.1", sha256="e5a4b455ab6bfbccbce3260673d9af8d1e4b21e19a2b6d0b6c1e1d7727613b7a")
# <     version("1.0.0", sha256="efd218bc9152abde0a8006489a2c432742f00283a114c1eeb6d25abc10f5862d")
# < 
# <     # https://github.com/hatchet/hatchet/issues/428
# <     depends_on("python@2.7:3.10.15", when="@:1.3.0", type=("build", "run"))
# <     depends_on("python@2.7:", when="@1.3.1:", type=("build", "run"))
# < 
# <     depends_on("py-setuptools", type="build")
# <     depends_on("py-matplotlib", type=("build", "run"))
# <     depends_on("py-numpy", type=("build", "run"))
# <     depends_on("py-pandas", type=("build", "run"))
# <     depends_on("py-pydot", type=("build", "run"))
# <     depends_on("py-pyyaml", type=("build", "run"))
# ---
# >     version('1.3.0', sha256='d77d071fc37863fdc9abc3fd9ea1088904cd98c6980a014a31e44595d2deac5e')
# >     version('1.2.0', sha256='1d5f80abfa69d1a379dff7263908c5c915023f18f26d50b639556e2f43ac755e')
# >     version('1.1.0', sha256='71bfa2881ef295294e5b4493acb8cce98d14c354e9ae59b42fb56a76d8ec7056')
# >     version('1.0.1', sha256='e5a4b455ab6bfbccbce3260673d9af8d1e4b21e19a2b6d0b6c1e1d7727613b7a')
# >     version('1.0.0', sha256='efd218bc9152abde0a8006489a2c432742f00283a114c1eeb6d25abc10f5862d')
# > 
# >     depends_on('python@2.7,3:', type=('build', 'run'))
# > 
# >     depends_on('py-setuptools', type='build')
# >     depends_on('py-matplotlib', type=('build', 'run'))
# >     depends_on('py-numpy',      type=('build', 'run'))
# >     depends_on('py-pandas',     type=('build', 'run'))
# >     depends_on('py-pydot',      type=('build', 'run'))
# >     depends_on('py-pyyaml',     type=('build', 'run'))
from spack.package import *


class PyHatchet(PythonPackage):
    """Hatchet is a performance tool for analyzing hierarchical performance data
    using a graph-indexed Pandas dataframe."""

    homepage = "https://github.com/hatchet/hatchet"
    url = "https://files.pythonhosted.org/packages/be/75/904c27e3d96d73d5743257caaf820564b0ac3be3497ec2765200ed5241f9/hatchet-1.3.1.tar.gz"
    tags = ["radiuss"]

    maintainers = ["slabasan", "bhatele", "tgamblin"]

    version("1.3.1", sha256="17b36abd4bc8c6d5fed452267634170159062ca3c2534199b1c8378f2f3f1f28")
    version("1.3.0", sha256="d77d071fc37863fdc9abc3fd9ea1088904cd98c6980a014a31e44595d2deac5e")
    version("1.2.0", sha256="1d5f80abfa69d1a379dff7263908c5c915023f18f26d50b639556e2f43ac755e")
    version("1.1.0", sha256="71bfa2881ef295294e5b4493acb8cce98d14c354e9ae59b42fb56a76d8ec7056")
    version("1.0.1", sha256="e5a4b455ab6bfbccbce3260673d9af8d1e4b21e19a2b6d0b6c1e1d7727613b7a")
    version("1.0.0", sha256="efd218bc9152abde0a8006489a2c432742f00283a114c1eeb6d25abc10f5862d")

    # https://github.com/hatchet/hatchet/issues/428
    depends_on("python@2.7:3.10.15", when="@:1.3.0", type=("build", "run"))
    depends_on("python@2.7:", when="@1.3.1:", type=("build", "run"))

    depends_on("py-setuptools", type="build")
    depends_on("py-matplotlib", type=("build", "run"))
    depends_on("py-numpy", type=("build", "run"))
    depends_on("py-pandas", type=("build", "run"))
    depends_on("py-pydot", type=("build", "run"))
    depends_on("py-pyyaml", type=("build", "run"))
