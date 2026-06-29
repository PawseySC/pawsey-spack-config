# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for the PennyLane-Qiskit plugin on setonix-q.
# This recipe is intentionally pinned to the validated 2026.08 quantum
# environment stack, using CUDA-enabled but non-MPI dependencies.

from spack.package import *


class PyPennylaneQiskit(PythonPackage):
    """PennyLane plugin exposing Qiskit devices."""

    homepage = "https://github.com/PennyLaneAI/pennylane-qiskit"
    pypi = "PennyLane-qiskit/pennylane_qiskit-0.44.0-py3-none-any.whl"

    license("Apache-2.0")

    # PyPI only publishes a pure-Python wheel for this release, no sdist.
    version(
        "0.44.0",
        sha256="8d8e7e8c45a8b3d87f18feda0dc69562b16a1eb58adbed8c76a7e2faddd94882",
        expand=False,
    )

    depends_on("python@3.11.6", type=("build", "run"))
    depends_on("py-pip", type="build")
    depends_on("py-wheel@0.41.2", type="build")
    depends_on("py-setuptools", type="build")

    depends_on(
        "py-qiskit@2.3.0+cuda~mpi cuda_arch=90",
        type=("build", "run"),
    )

    depends_on(
        "py-pennylane@0.45.0+cuda+gpu+tensor+mpi cuda_arch=90",
        type=("build", "run"),
    )

    depends_on("py-qiskit-ibm-runtime@0.43.0", type=("build", "run"))

    depends_on("py-sympy", type=("build", "run"))
    depends_on("py-networkx@3.1", type=("build", "run"))

    depends_on("py-qiskit-aer@0.17.2", type=("build", "run"))