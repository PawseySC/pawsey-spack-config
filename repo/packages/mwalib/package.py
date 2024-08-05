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
    version("1.4.0", tag="v1.4.0")
    version("1.3.3", tag="v1.3.3")

    variant("python", default=True, description="Build and install Python bindings.")

    depends_on("rust@1.64.0:", type="build")
    depends_on("cfitsio@3.49")
    depends_on("curl") # because cfitsio does not --disable-curl by default
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

    def setup_build_environment(self, env):
        env.set('MWALIB_LINK_STATIC_CFITSIO', 1)
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")
        env.set('RUST_BACKTRACE', 1)

    def install(self, spec, prefix):
        os.system("env")
        cargo = Executable("cargo")
        with fs.working_dir(self.stage.source_path):
            cargo("build", "--release", "--features=cfitsio-static")
            shutil.copytree("include", f"{prefix}/include")
            os.mkdir(f"{prefix}/lib")
            release = Path("target/release/")
            for f in release.iterdir():
                if f.name.startswith("libmwalib."):
                    shutil.copy2(f"{f}", f"{prefix}/lib/")
            if '+python' in spec:
                maturin = which("maturin")
                pip = which("pip3")
                maturin("build", "--release", "--features", "python,cfitsio-static", "--strip")
                whl_file =list(os.listdir("target/wheels"))[0]
                pip("install", f"--prefix={prefix}", f"target/wheels/{whl_file}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--release", "--lib", "--features=cfitsio-static")

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
        if "+python" in self.spec:
            python_version = self.spec["python"].version.string
            python_version = python_version[:python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")

    def setup_dependent_run_environment(self, env, dependent_spec):
        if "+python" in self.spec and  dependent_spec.package.extends(self.spec):
            python_version = self.spec["python"].version.string
            python_version = python_version[:python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")


"""
salloc --nodes=1 --partition=gpu-highmem --account=pawsey0875-gpu -t 00:30:00 --gres=gpu:1

module load spack/default

spack install --test=root --reuse mwalib@main +python
spack load 'mwalib@main'

# catch undefined variables
( set -u; echo MYSOFTWARE: $MYSOFTWARE$'\n'MYSCRATCH: $MYSCRATCH )

# Astro stuff
export obsid=1087251016
export outdir="${MYSCRATCH}/${obsid}"
mkdir -p $outdir
export metafits="${outdir}/${obsid}.metafits"
[ -f "$metafits" ] || wget -O "$metafits" $'http://ws.mwatelescope.org/metadata/fits?obs_id='${obsid}
wget https://raw.githubusercontent.com/MWATelescope/mwalib/main/examples/mwalib-print-context.py
python mwalib-print-context.py -m $metafits
"""