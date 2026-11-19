# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Modified/backported the Spack py-rustworkx recipe to keep Cargo
# registry/cache files in the Spack stage and add the explicit Rust build
# dependency required by rustworkx 0.15.1.

from spack.package import *


class PyRustworkx(PythonPackage):
    """Rustworkx is a high-performance graph library written in Rust."""

    homepage = "https://github.com/Qiskit/rustworkx"
    pypi = "rustworkx/rustworkx-0.12.1.tar.gz"

    license("Apache-2.0")

    version("0.15.1", sha256="0e0cc86599f979285b2ab9c357276f3272f3fcb3b2df5651a6bf9704c570d4c1")
    version("0.15.0", sha256="41a50586c48367c80eebc26809105c0c47db47b1d12a5078efa94d8d1f3850a4")
    version("0.14.2", sha256="bd649322c0649b71fa18cc70a9af027b549560415fa860d6894736029c277b13")
    version("0.14.1", sha256="62104ecb0b3d4c2cfdb8b45dc38646bd45760c43fabc70ded9112712d01ea1c9")
    version("0.14.0", sha256="d630e3dd2984bb3dfa1cc9af5d960c3b970a5c0512551d8340996e9e61e2ca44")
    version("0.13.2", sha256="0276cf0b989211859e8797b67d4c16ed6ac9eb32edb67e0a47e70d7d71e80574")
    version("0.13.1", sha256="e76c67896030c9edd9823c2937ac6bfa1ce58bae580a8214596b687b6011a487")
    version("0.13.0", sha256="9d42059f57a9794c9cbe1c9fc3bca3b72ab00f9d8f24a0efb5ac3829c7f7d6b8")
    version("0.12.1", sha256="13a19a2f64dff086b3bffffb294c4630100ecbc13634b4995d9d36a481ae130e")
    version("0.12.0", sha256="0b871e1463a6677d0fd2fc00adfb774283045d38740bd1b7ea5a1a729de06aa1")

    depends_on("python@3.8:", when="@0.15:", type=("build", "run"))
    depends_on("python@3.7:", type=("build", "run"))
    depends_on("rust@1.70:", when="@0.15.1:", type="build")
    depends_on("rust", when="@:0.15.0", type="build")
    depends_on("py-setuptools", type="build")
    depends_on("py-wheel", type="build")
    depends_on("py-setuptools-rust", type="build")
    depends_on("py-numpy@1.16:", type=("build", "run"))

    def setup_build_environment(self, env):
        env.set("CARGO_HOME", join_path(self.stage.source_path, ".cargo"))
        env.set("CARGO_BUILD_JOBS", str(make_jobs))
        env.set("RUST_BACKTRACE", "1")
