# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for the Qiskit IBM Runtime client, a runtime
# dependency of the PennyLane-Qiskit plugin on setonix-q. Pinned to the 0.43
# series to match PennyLane-Qiskit 0.44.0 (qiskit-ibm-runtime~=0.43.0).

from spack.package import *


class PyQiskitIbmRuntime(PythonPackage):
    """IBM Quantum client for Qiskit Runtime."""

    homepage = "https://github.com/Qiskit/qiskit-ibm-runtime"
    url = "https://files.pythonhosted.org/packages/b1/8b/5a50b62a98800a8c402cfc342e13ec93e33b03211ddd86998ba7001a3f35/qiskit_ibm_runtime-0.43.0.tar.gz"

    license("Apache-2.0")

    version("0.43.0", sha256="1aacbe10eb7698c03bd62e09d88ef81b095f1c4a9c7e76dba9e58b983d0273e3")

    depends_on("python@3.9:", type=("build", "run"))
    depends_on("py-setuptools@40.6:", type="build")
    depends_on("py-setuptools-scm@6.2:", type="build")

    depends_on("py-requests@2.19:", type=("build", "run"))
    depends_on("py-requests-ntlm@1.1:", type=("build", "run"))
    depends_on("py-numpy@1.13:", type=("build", "run"))
    depends_on("py-urllib3@1.21.1:", type=("build", "run"))
    depends_on("py-python-dateutil@2.8:", type=("build", "run"))
    depends_on("py-ibm-platform-services@0.22.6:", type=("build", "run"))
    depends_on("py-pydantic@2.5:", type=("build", "run"))
    depends_on("py-qiskit@1.4.1:", type=("build", "run"))
    depends_on("py-packaging", type=("build", "run"))
