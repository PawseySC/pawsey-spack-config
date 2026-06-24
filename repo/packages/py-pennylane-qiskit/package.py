# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for the PennyLane-Qiskit plugin on setonix-q. It
# layers the plugin on top of the Pawsey CUDA/cuQuantum py-qiskit and py-pennylane
# recipes, replacing the previous custom (non-Spack) install.

from spack.package import *


class PyPennylaneQiskit(PythonPackage):
    """PennyLane plugin exposing Qiskit devices (qiskit.aer, qiskit.basicsim, qiskit.remote)."""

    homepage = "https://github.com/PennyLaneAI/pennylane-qiskit"
    url = "https://files.pythonhosted.org/packages/25/e6/0fdec53fc3e063345fcb41206683d7dc4acc26db0ecec53f5e55a6a8d49f/pennylane_qiskit-0.44.0-py3-none-any.whl"

    license("Apache-2.0")

    # PyPI only publishes a (pure-Python) wheel for this release, no sdist.
    version(
        "0.44.0",
        sha256="8d8e7e8c45a8b3d87f18feda0dc69562b16a1eb58adbed8c76a7e2faddd94882",
        expand=False,
    )

    depends_on("python@3.11:", type=("build", "run"))

    # PennyLane-Qiskit 0.44.0 pins qiskit<=2.2.2 upstream, but the Pawsey
    # CUDA/cuQuantum py-qiskit (2.3.0, Aer 0.17.2) has been validated with this
    # plugin on setonix-q, so the upper bound is intentionally relaxed here
    # (mirroring the previous --no-deps custom install). py-qiskit provides both
    # the qiskit and qiskit-aer Python packages.
    depends_on("py-qiskit@2.3.0:", type=("build", "run"))
    depends_on("py-qiskit-ibm-runtime@0.43.0:0.43", type=("build", "run"))
    depends_on("py-pennylane@0.44:", type=("build", "run"))
    depends_on("py-sympy", type=("build", "run"))
    depends_on("py-networkx@2.2:", type=("build", "run"))
