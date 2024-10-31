from spack.package import *

class Hyperdrive(Package, ROCmPackage, CudaPackage):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/mwa_hyperdrive"
    git = "https://github.com/MWATelescope/mwa_hyperdrive.git"

    maintainers = ["d3v-null"]

    version("main",  branch="main")
    version("0.4.1", tag="v0.4.1")

    # unknown issue on setonix when enabled https://github.com/PawseySC/pawsey-spack-config/pull/280#issuecomment-2296128762
    variant("cfitsio-static", default=False, description="Enable the fitsio_src feature of the fitsio-sys crate.")
    variant("hdf5-static", default=False, description="Link statically to hdf5 via hdf5-sys crate.")
    variant("plotting", default=True, description="Enable plotting subcommands like plot-solutions")
    variant("portable", default=True, description="Disable native CPU optimizations")

    depends_on("rust@1.64.0:")
    depends_on("cmake", type="build")
    # cfitsio > 4 introduces a breaking change, is incompatible with mwalib.
    # default spack cfitsio does not give the +reentrant option
    depends_on("cfitsio@3.49 +reentrant")
    # hdf5-sys v0.8 built with 110 api https://crates.io/crates/hdf5-sys/0.8.0
    depends_on("hdf5@1.10 +cxx ~mpi api=v110", when="~hdf5-static")

    depends_on("aoflagger@3.0.0:") # because of Birli
    depends_on("erfa") # because of Marlu
    depends_on("fontconfig", when="+plotting")
    depends_on("libpng", when="+plotting")

    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")
        if self.spec.satisfies("+rocm"):
            amdgpu_target = ",".join(self.spec.variants["amdgpu_target"].value)
            env.set('HYPERDRIVE_HIP_ARCH', amdgpu_target)
            hip_spec = self.spec["hip"]
            rocm_dir = hip_spec.prefix
            # print(f"rocm_dir: {rocm_dir}, amdgpu_target: {amdgpu_target}")
            if hip_spec.satisfies("@6:"):
                env.set('HIP_PATH', rocm_dir)
            else:
                env.set('HIP_PATH', rocm_dir)
                env.set('ROCM_PATH', rocm_dir)
        if self.spec.satisfies("+cuda"):
            cuda_arch = spec.variants["cuda_arch"].value
            env.set('HYPERDRIVE_CUDA_COMPUTE', cuda_arch)
            cuda_dir = self.spec["cuda"].prefix
            # print(f"cuda_dir: {cuda_dir}, cuda_arch: {cuda_arch}")
        if self.spec.satisfies("~portable"):
            env.append_flags("RUSTFLAGS", f"-C target-cpu=native")

    def get_features(self):
        features = []
        if self.spec.satisfies("+cfitsio-static"):
            features += ["cfitsio-static"]
        if self.spec.satisfies("+hdf5-static"):
            features += ["hdf5-static"]
        if self.spec.satisfies("+rocm"):
            features += ["hip"]
        if self.spec.satisfies("+cuda"):
            features += ["cuda"]
        if self.spec.satisfies("+plotting"):
            features += ["plotting"]
        return features

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        features = self.get_features()
        cargo("install", "--path=.", f"--root={prefix}", "--no-default-features", f"--features={','.join(features)}", "--locked")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        features = self.get_features()
        # TODO: more elegant way of setting beam file from variants?
        # e.g. /scratch/references/mwa/mwa_full_embedded_element_pattern.h5
        # see: <https://pawsey.atlassian.net/servicedesk/customer/portal/3/GS-29129>
        # Executable("ln")("-s", "/software/projects/mwaeor/dev/mwa_full_embedded_element_pattern.h5", "mwa_full_embedded_element_pattern.h5")
        cargo("test", "--release", "--lib", "--no-default-features", f"--features={','.join(features)}")
