# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


from spack.package import *


class GiantSquid(Package):
    """client for Murchison Widefield Array (MWA) All-Sky Virtual Observatory (ASVO)"""

    homepage = "https://github.com/MWATelescope/giant-squid"
    git = "https://github.com/MWATelescope/giant-squid.git"

    maintainers = ["gsleap", "d3v-null"]

    version("2.1.2", tag="v2.1.2")
    version("2.1.1", tag="v2.1.1")
    version("2.1.0", tag="v2.1.0")
    version("2.2.0", tag="v2.2.0")

    depends_on("rust@1.82.0:", when="@1.1.0:", type="build")

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set("CARGO_HOME", f"{build_dir}/.cargo")
        env.set("RUST_BACKTRACE", 1)

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        cargo("install", "--path=.", f"--root={prefix}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--release", "--lib")
