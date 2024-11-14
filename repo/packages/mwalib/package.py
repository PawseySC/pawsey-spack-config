# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


import os
import llnl.util.filesystem as fs
from pathlib import Path
import shutil

from spack.package import *


class Mwalib(Package):
    """Read Murchison Widefield Array (MWA) raw visibilities, voltages and metadata"""

    homepage = "https://github.com/MWATelescope/mwalib"
    git = "https://github.com/MWATelescope/mwalib.git"

    maintainers = ["d3v-null"]

    version("main", branch="main")
    version("1.8.2", tag="v1.8.2")
    version("1.5.0", tag="v1.5.0")
    version("1.4.0", tag="v1.4.0")
    version("1.3.3", tag="v1.3.3")

    variant("python", default=True, description="Build and install Python bindings.")

    # unknown issue on setonix when enabled https://github.com/PawseySC/pawsey-spack-config/pull/280#issuecomment-2296128762
    variant("cfitsio-static", default=False, description="Enable the fitsio_src feature of the fitsio-sys crate.")
    variant("portable", default=True, description="Disable native CPU optimizations")

    depends_on("rust@1.64.0:", type="build")

    # cfitsio > 4 introduces a breaking change, is incompatible with mwalib.
    # default spack cfitsio does not give the +reentrant option
    depends_on("cfitsio@3.49 +reentrant")

    depends_on("py-maturin", when="+python")
    depends_on("py-numpy", type=("build", "run"), when="+python")
    depends_on("python", type=("build", "run"), when="+python")
    depends_on("py-pip", type="build", when="+python")

    sanity_check_is_file = [
        join_path("include", "mwalib.h"),
        join_path("lib", "libmwalib.a"),
        join_path("lib", "libmwalib.so"),
    ]
    test_requires_compiler = True

    def get_features(self):
        features = []
        if self.spec.satisfies('+cfitsio-static'):
            features += ["cfitsio-static"]
        return features

    def get_build_args(self, python=False):
        build_args = ["--release"]
        features = self.get_features()
        if python:
            features += ["python"]
        if features:
            build_args += [f"--features={','.join(features)}"]
        # build_args += ["--verbose"] # for debugging
        return build_args

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")
        # env.set('RUST_BACKTRACE', 1) # for debugging
        if self.spec.satisfies("+cfitsio-static"):
            env.set('MWALIB_LINK_STATIC_CFITSIO', 1)
        if self.spec.satisfies("~portable"):
            env.append_flags("RUSTFLAGS", f"-C target-cpu=native")

    def install(self, spec, prefix):
        # os.system("env") # for debugging
        cargo = Executable("cargo")
        with fs.working_dir(self.stage.source_path):
            cargo("build", *self.get_build_args())
            shutil.copytree("include", f"{prefix}/include")
            os.mkdir(f"{prefix}/lib")
            release = Path("target/release/")
            for f in release.iterdir():
                if f.name.startswith("libmwalib."):
                    shutil.copy2(f"{f}", f"{prefix}/lib/")
            if spec.satisfies("+python"):
                maturin = which("maturin")
                pip = which("pip3")
                maturin("build", *self.get_build_args(python=True))
                whl_file =list(os.listdir("target/wheels"))[0]
                pip("install", f"--prefix={prefix}", f"target/wheels/{whl_file}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--lib", *self.get_build_args())

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def test_examples(self):
        cc = which(os.environ["CC"])
        exe = "mwalib-print-context"
        cc(
            f"examples/{exe}.c",
            f"-L{self.prefix.lib}",
            f"-I{self.prefix.include}",
            "-lm", "-lpthread", "-ldl",
            "-lmwalib",
            "-o", exe,
        )
        Executable(f"./{exe}")("test_files/1384808344/1384808344_metafits.fits")

    def setup_run_environment(self, env):
        if not self.spec.satisfies("+cfitsio-static"):
            env.prepend_path("LD_LIBRARY_PATH", self.spec["cfitsio"].prefix.lib)
        if self.spec.satisfies("+python"):
            python_version = self.spec["python"].version.string
            python_version = python_version[:python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")

    def setup_dependent_run_environment(self, env, dependent_spec):
        if not self.spec.satisfies("+cfitsio-static"):
            env.prepend_path("LD_LIBRARY_PATH", self.spec["cfitsio"].prefix.lib)
        if self.spec.satisfies("+python") and dependent_spec.package.extends(self.spec):
            python_version = self.spec["python"].version.string
            python_version = python_version[:python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")
