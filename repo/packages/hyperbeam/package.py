# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)


from spack.package import *

import os
import llnl.util.filesystem as fs
from pathlib import Path
import shutil


class Hyperbeam(Package, ROCmPackage, CudaPackage):
    """Primary beam code for the Murchison Widefield Array (MWA) radio telescope."""

    homepage = "https://github.com/MWATelescope/mwa_hyperbeam"
    git = "https://github.com/MWATelescope/mwa_hyperbeam.git"

    maintainers = ["d3v-null", "gsleap"]

    version("main", branch="main")
    version("0.10.2", tag="v0.10.2")
    version("0.10.0", tag="v0.10.0")
    version("0.9.3", tag="v0.9.3")
    version("0.8.0", tag="v0.8.0")
    version("0.7.2", tag="v0.7.2")
    version("0.6.1", tag="v0.6.1")
    version("0.5.0", tag="v0.5.0")

    variant("python", default=True, description="Build and install Python bindings.")
    variant("hdf5-static", default=False, description="Link statically to hdf5 via hdf5-sys crate.")
    variant("portable", default=True, description="Disable native CPU optimizations")

    depends_on("rust@1.64.0:", type="build")
    depends_on("rust@1.80.0:", type="build", when="@0.10.0:")
    depends_on("cmake", type="build")

    # cfitsio > 4 introduces a breaking change, is incompatible with mwalib.
    # default spack cfitsio does not give the +reentrant option
    depends_on("cfitsio@3.49 +reentrant")

    depends_on("hdf5@1.10 +cxx ~mpi api=v110", when="~hdf5-static")
    depends_on("py-maturin", when="+python")

    # this is the only version of patchelf that has been found to work with maturin. patchelf@0.18
    # corrupts the dynamic libraries, making them unusable.
    # https://github.com/PawseySC/pawsey-spack-config/pull/280#issuecomment-2258095785
    depends_on("patchelf@0.17.2", type=("build", "run"), when="+python")

    depends_on("py-numpy", type=("build", "run"), when="+python")
    depends_on("python", type=("build", "run"), when="+python")
    depends_on("py-pip", type="build", when="+python")
    depends_on("erfa", when="@0.5.0")

    conflicts("+rocm", when="@:0.6.0")  # early hip support was added in 0.6.0

    sanity_check_is_file = [
        join_path("include", "mwa_hyperbeam.h"),
        join_path("lib", "libmwa_hyperbeam.a"),
        join_path("lib", "libmwa_hyperbeam.so"),
    ]
    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set("CARGO_HOME", f"{build_dir}/.cargo")
        if self.spec.satisfies("+rocm"):
            amdgpu_target = ",".join(self.spec.variants["amdgpu_target"].value)
            env.set("HYPERBEAM_HIP_ARCH", amdgpu_target)
            hip_spec = self.spec["hip"]
            rocm_dir = hip_spec.prefix
            # print(f"rocm_dir: {rocm_dir}, amdgpu_target: {amdgpu_target}")
            if hip_spec.satisfies("@6:"):
                env.set("HIP_PATH", rocm_dir)
            else:
                env.set("HIP_PATH", rocm_dir)
                env.set("ROCM_PATH", rocm_dir)
        if self.spec.satisfies("+cuda"):
            cuda_arch = spec.variants["cuda_arch"].value
            env.set("HYPERBEAM_CUDA_COMPUTE", cuda_arch)
            cuda_dir = self.spec["cuda"].prefix
            # print(f"cuda_dir: {cuda_dir}, cuda_arch: {cuda_arch}")
        if self.spec.satisfies("~portable"):
            env.append_flags("RUSTFLAGS", f"-C target-cpu=native")

    def get_features(self):
        features = []
        if self.spec.satisfies("+hdf5-static"):
            features += ["hdf5-static"]
        if self.spec.satisfies("+rocm"):
            features += ["hip"]
        if self.spec.satisfies("+cuda"):
            features += ["cuda"]
        return features

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        features = self.get_features()
        with fs.working_dir(self.stage.source_path):
            cargo("build", "--locked", "--release", f"--features={','.join(features)}")
            shutil.copytree("include", f"{prefix}/include")
            os.mkdir(f"{prefix}/lib")
            release = Path("target/release/")
            for f in release.iterdir():
                if f.name.startswith("libmwa_hyperbeam."):
                    shutil.copy2(f"{f}", f"{prefix}/lib/")
            if self.spec.satisfies("+python"):
                maturin = which("maturin")
                pip = which("pip3")
                pyfeatures = ["python"] + features
                maturin("build", "--release", f"--features={','.join(pyfeatures)}", "--strip")
                whl_file = list(os.listdir("target/wheels"))[0]
                pip("install", f"--prefix={prefix}", f"target/wheels/{whl_file}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        features = self.get_features()
        # TODO: more elegant way of setting beam file from variants?
        Executable("ln")(
            "-s",
            "/scratch/references/mwa/beam-models/mwa_full_embedded_element_pattern.h5",
            "mwa_full_embedded_element_pattern.h5",
        )
        cargo("test", "--release", "--lib", f"--features={','.join(features)}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def test_cc_examples(self):
        cc = which(os.environ["CC"])
        cc_exes = ["analytic", "analytic_parallel", "fee", "fee_parallel", "fee_parallel_omp"]
        if self.spec.satisfies("+rocm") or self.spec.satisfies("+cuda"):
            cc_exes += ["fee_gpu", "analytic_gpu"]
        for exe in cc_exes:
            cc(
                f"examples/{exe}.c",
                f"-L{self.prefix.lib}",
                f"-I{self.prefix.include}",
                "-lm",
                "-lpthread",
                "-ldl",
                "-lmwa_hyperbeam",
                "-o",
                exe,
            )
            args = []
            if "fee" in exe:
                args += ["mwa_full_embedded_element_pattern.h5"]
            Executable(f"./{exe}")(*args)

    def setup_run_environment(self, env):
        if self.spec.satisfies("+python"):
            python_version = self.spec["python"].version.string
            python_version = python_version[: python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")

    def setup_dependent_run_environment(self, env, dependent_spec):
        if self.spec.satisfies("+python") and dependent_spec.package.extends(self.spec):
            python_version = self.spec["python"].version.string
            python_version = python_version[: python_version.rfind(".")]
            env.prepend_path("PYTHONPATH", f"{self.spec.prefix}/lib/python{python_version}/site-packages")
