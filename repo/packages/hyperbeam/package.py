# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


from spack.package import *

import os
import llnl.util.filesystem as fs
from pathlib import Path
import shutil


class Hyperbeam(Package):
    """Primary beam code for the Murchison Widefield Array (MWA) radio telescope."""

    homepage = "https://github.com/MWATelescope/mwa_hyperbeam"
    git = "https://github.com/MWATelescope/mwa_hyperbeam.git"

    maintainers = ["d3v-null"]

    version("0.8.0", tag="v0.8.0")
    variant("python", default=True, description="Build and install Python bindings.")

    depends_on("rust@1.64.0:", type="build")
    depends_on("cfitsio@3.49")
    depends_on("curl") # because cfitsio does not --disable-curl by default
    depends_on("hdf5 +cxx ~mpi api=v110")
    depends_on("py-maturin", when="+python")
    depends_on("py-numpy", type=("build", "run"), when="+python")
    depends_on("python", type=("build", "run"), when="+python")
    depends_on("py-pip", type="build", when="+python")

    sanity_check_is_file = [
        join_path("include", "mwa_hyperbeam.h"),
        join_path("lib", "libmwa_hyperbeam.a"),
        join_path("lib", "libmwa_hyperbeam.so"),
    ]
    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")

    def install(self, spec, prefix):
        os.system("env")
        cargo = Executable("cargo")
        cargo("generate-lockfile")
        with fs.working_dir(self.stage.source_path):
            cargo("build", "--locked", "--release", "--features=hdf5-static")
            shutil.copytree("include", f"{prefix}/include")
            os.mkdir(f"{prefix}/lib")
            release = Path("target/release/")
            for f in release.iterdir():
                if f.name.startswith("libmwa_hyperbeam."):
                    shutil.copy2(f"{f}", f"{prefix}/lib/")
            if '+python' in spec:
                maturin = which("maturin")
                pip = which("pip3")
                maturin("build", "--release", "--features", "python,hdf5-static", "--strip")
                whl_file =list(os.listdir("target/wheels"))[0]
                pip("install", f"--prefix={prefix}", f"target/wheels/{whl_file}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--release", "--lib", "--features=hdf5-static")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def test_examples(self):
        cc = which(os.environ["CC"])
        exe = "fee"
        cc(
            f"examples/{exe}.c",
            f"-L{self.prefix.lib}",
            f"-I{self.prefix.include}",
            "-lm", "-lpthread", "-ldl",
            "-lmwa_hyperbeam"
            f"{exe}.cpp",
            "-o", exe,
        )
        cc_example = which(exe)
        cc_example()

    def setup_run_environment(self, env):
        python_version = self.spec["python"].version.string
        python_version = python_version[:python_version.rfind(".")]
        env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")

    def setup_dependent_run_environment(self, env, dependent_spec):
        if dependent_spec.package.extends(self.spec):
            python_version = self.spec["python"].version.string
            python_version = python_version[:python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")
