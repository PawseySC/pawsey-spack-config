# Copyright 2013-2024 Lawrence Livermore National Security, LLC and other
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
#     spack install py-scalene
#
# You can edit this file again by typing:
#
#     spack edit py-scalene
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

from spack.package import *


class PyScalene(PythonPackage):
    """FIXME: Put a proper description of your package here."""

    homepage = "https://github.com/plasma-umass/scalene"
    pypi = "scalene/scalene-2.0.0.tar.gz"
    git = "https://github.com/plasma-umass/scalene.git"

    maintainers("emeryberger")

    license("Apache-2.0", checked_by="gemeryberger")

    version("2.0.0", sha256="a43158fe7537b0e0db14a213e2e09692e3abf92c3e004ef2b64d8fff21049544")

    """
    dependencies
    "rich>=10.7.0",
    "cloudpickle>=2.2.1",
    # "pynvml>=11.0.0,<=11.5",
    "nvidia-ml-py>=12.555.43; platform_system !='Darwin'",
    "Jinja2>=3.0.3",
    "psutil>=5.9.2",
    "numpy>=1.24.0,!=1.27; python_version < '3.14'",
    "numpy>=2.3.4; python_version >= '3.14'",
    "astunparse>=1.6.3; python_version < '3.9'",
    "pydantic>=2.6",
    "pyyaml>=6.0",
    """
    # Based on PyPI wheel availability
    with default_args(type=("build", "link", "run")):
        depends_on("python@3.8:3.14", when="@2:")

    with default_args(type=("build", "run")):
        depends_on("py-setuptools@70:", when="@2:")
        depends_on("py-cython", when="@2:")

    with default_args(type=("build", "link", "run")):
        depends_on("py-numpy@1.24.0:", when="python@:3.13")
        depends_on("py-numpy@2.3.43:", when="python@3.14:")
        depends_on("py-rich@10.7.0:", when="@2:")
        depends_on("py-cloudpickle@2.2.1:", when="@2:")
        depends_on("py-pydantic@2.6:", when="@2")
        depends_on("py-pyyaml@6:", when="@2")
        depends_on("py-jinja2@3.0.3", when="@2")
        depends_on("py-astunparse@1.6.3", when="@2")


    def config_settings(self, spec, prefix):
        # FIXME: Add configuration settings to be passed to the build backend
        # FIXME: If not needed, delete this function
        settings = {}
        return settings
