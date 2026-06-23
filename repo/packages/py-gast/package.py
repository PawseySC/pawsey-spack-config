# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Modified/backported the Spack py-gast recipe with 0.7.0 support for
# PennyLane/diastatic-malt.

from spack.package import *


class PyGast(PythonPackage):
    """Python AST that abstracts the underlying Python version."""

    homepage = "https://github.com/serge-sans-paille/gast/"
    pypi = "gast/gast-0.7.0.tar.gz"

    license("BSD-3-Clause")

    version("0.7.0", sha256="0bb14cd1b806722e91ddbab6fb86bba148c22b40e7ff11e248974e04c8adfdae")

    depends_on("python@2.7:2.8,3.4:", type=("build", "run"))
    depends_on("py-setuptools", type="build")
