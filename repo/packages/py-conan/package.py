# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Modified/backported the Spack py-conan recipe with 1.65.0 support
# for the Qiskit Aer build.

from spack.package import *


class PyConan(PythonPackage):
    """Conan C/C++ package manager."""

    homepage = "https://conan.io"
    pypi = "conan/conan-1.65.0.tar.gz"

    license("MIT")

    version("1.65.0", sha256="2fc5c8d681d94ccb9c0f273c29e4a8c78a8ea1b25295dc6ca17f9a715935c2df")
    version("1.52.0", sha256="184761f16d00fde17615e60125d2f14fca692ffba7666cc7d6d834fc3858cf82")

    depends_on("python@3.6:", type=("build", "run"))
    depends_on("py-setuptools", type="build")
    depends_on("py-requests@2.25:2", type=("build", "run"))
    depends_on("py-urllib3@1.26.6:1.26", type=("build", "run"))
    depends_on("py-colorama@0.3.3:0.4", type=("build", "run"))
    depends_on("py-pyyaml@3.11:6.0", when="@:1.52", type=("build", "run"))
    depends_on("py-pyyaml@3.11:6.0.999", when="@1.65:", type=("build", "run"))
    depends_on("py-patch-ng@1.17.4:1.17", type=("build", "run"))
    depends_on("py-fasteners@0.14.1:", type=("build", "run"))
    depends_on("py-six@1.10.0:1.16.0", type=("build", "run"))
    depends_on("py-node-semver@0.6.1", type=("build", "run"))
    depends_on("py-distro@1.0.2:1.6.0", when="@:1.52 platform=linux", type=("build", "run"))
    depends_on("py-distro@1.0.2:1.8.0", when="@1.65: platform=linux", type=("build", "run"))
    depends_on("py-pygments@2.0:2", type=("build", "run"))
    depends_on("py-tqdm@4.28.1:4", type=("build", "run"))
    depends_on("py-jinja2@3.0:3", type=("build", "run"))
    depends_on("py-python-dateutil@2.7.0:2.999", type=("build", "run"))
