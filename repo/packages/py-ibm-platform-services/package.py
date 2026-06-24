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
    url = "https://files.pythonhosted.org/packages/6f/54/a20f5d88f920748fe3cc2df812dfcc2db5ff777a4836e5b778538e9af71a/ibm_platform_services-0.75.2.tar.gz"

    license("Apache-2.0")

    version("0.75.2", sha256="38618dd49adf609c37d583b0758fb4ebf0943693089cf6f82002f11a8e5590e5")

    depends_on("python@3.10:", type=("build", "run"))
    depends_on("py-setuptools@67.7.2:", type="build")

    depends_on("py-ibm-cloud-sdk-core@3.24.4:3", type=("build", "run"))
