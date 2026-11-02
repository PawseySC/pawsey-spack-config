# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for the IBM Cloud Platform Services client, a runtime
# dependency of the Qiskit IBM Runtime client pulled in by the PennyLane-Qiskit
# plugin.

from spack.package import *


class PyIbmPlatformServices(PythonPackage):
    """Python client library to interact with various IBM Cloud Platform Service APIs."""

    homepage = "https://github.com/IBM/platform-services-python-sdk"
    url = "https://files.pythonhosted.org/packages/17/a3/1edc2d54b2fd3c31ef0339e101f72b662718494a0d51c50b79036cf4c2d6/ibm-platform-services-0.44.0.tar.gz"

    license("Apache-2.0")

    # Pawsey: pinned to 0.44.0, the newest release that accepts the builtin-
    # compatible py-ibm-cloud-sdk-core 3.16 series (newer releases require
    # ibm-cloud-sdk-core>=3.17, which pulls PyJWT>=2.8 not present in the
    # Spack 0.23.1 builtin repository).
    version("0.44.0", sha256="ee432623095154013c4aaf978558424552e9e2573098949d9ad363d61d5a81c8")

    depends_on("python@3.8:", type=("build", "run"))
    depends_on("py-setuptools", type="build")

    depends_on("py-requests@2.31:2", type=("build", "run"))
    depends_on("py-urllib3@1.26:1", type=("build", "run"))
    depends_on("py-python-dateutil@2.5.3:2", type=("build", "run"))
    depends_on("py-ibm-cloud-sdk-core@3.16.7:3", type=("build", "run"))
