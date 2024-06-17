from spack.package import *

class Birli(Package):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/birli"
    git = "https://github.com/MWATelescope/birli.git"

    maintainers = ["d3v-null"]

    version("0.10.0", tag="v0.8.0")

    depends_on("rust@1.64.0:", type="build")
    depends_on("cfitsio@3.49")
    depends_on("aoflagger@3.2.0:")
    depends_on("erfa") # because of Marlu

    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        cargo("generate-lockfile")
        cargo("install", "--path=.", f"--root={prefix}", "--features=cfitsio-static")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        cargo("test", "--release", "--lib", "--features=cfitsio-static")

