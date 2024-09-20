from spack.package import *

class Birli(Package):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/birli"
    git = "https://github.com/MWATelescope/birli.git"

    maintainers = ["d3v-null"]

    version("main", branch="main")
    version("0.13.0", tag="v0.13.0")
    version("0.12.0", tag="v0.12.0")
    version("0.10.0", tag="v0.10.0")

    # unknown issue on setonix when enabled https://github.com/PawseySC/pawsey-spack-config/pull/280#issuecomment-2296128762
    variant("cfitsio-static", default=False, description="Enable the fitsio_src feature of the fitsio-sys crate.")
    variant("rustc-cpu", default="native", description="Target a specific CPU in rustc, e.g. znver3")

    depends_on("rust@1.64.0:", type="build")
    depends_on("cmake", type="build")

    # cfitsio > 4 introduces a breaking change, is incompatible with mwalib.
    # default spack cfitsio does not give the +reentrant option
    depends_on("cfitsio@3.49 +reentrant")

    depends_on("aoflagger@3.0.0:")
    depends_on("erfa") # because of Marlu

    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")
        if self.spec.satisfies("+cfitsio-static"):
            env.set('MWALIB_LINK_STATIC_CFITSIO', 1)
        if (target_cpu:=self.spec.variants["rustc-cpu"].value):
            env.append_flags("RUSTFLAGS", f"-C target-cpu={target_cpu}")

    def get_features(self):
        features = []
        if self.spec.satisfies('+cfitsio-static'):
            features += ["cfitsio-static"]
        return features

    def get_cargo_args(self):
        args = []
        if (features:=self.get_features()):
            args += [f"--features={','.join(features)}"]
        # args += ["--verbose"] # for debugging
        return args

    def install(self, spec, prefix):
        # os.system("env") # for debugging
        cargo = Executable("cargo")
        features = self.get_features()
        cargo("install", "--path=.", "--locked", f"--root={prefix}", *self.get_cargo_args())

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        features = self.get_features()
        cargo("test", "--release", "--lib", *self.get_cargo_args())

    def setup_run_environment(self, env):
        if not self.spec.satisfies("+cfitsio-static"):
            env.prepend_path("LD_LIBRARY_PATH", self.spec["cfitsio"].prefix.lib)