from spack.package import *

class Hyperdrive(Package):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/mwa_hyperdrive"
    git = "https://github.com/MWATelescope/mwa_hyperdrive.git"

    maintainers = ["d3v-null"]

    version("0.3.0", tag="v0.3.0")

    variant("plotting", default=True, description="Enable plotting subcommands like plot-solutions")

    depends_on("rust@1.68.0:", type="build")
    depends_on("cfitsio@3.49")
    depends_on("aoflagger@3.2.0:") # because of Birli
    depends_on("erfa") # because of Marlu
    depends_on("hdf5@1.10: +cxx ~mpi api=v110")
    depends_on("fontconfig", when="+plotting")
    depends_on("libpng", when="+plotting")

    # TODO: no version of rocm5 works.
    # depends_on("rocm@6:")

    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        features = ["cfitsio-static", "hdf5-static"]
        if '+plotting' in spec:
            features += ["plotting"]
        cargo("install", "--path=.", f"--root={prefix}", "--no-default-features", f"--features={','.join(features)}")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--release", "--lib", "--no-default-features", "--features=cfitsio-static,hdf5-static")