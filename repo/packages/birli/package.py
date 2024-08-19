from spack.package import *

class Birli(Package):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/birli"
    git = "https://github.com/MWATelescope/birli.git"

    maintainers = ["d3v-null"]

    version("main", branch="main")
    version("0.12.0", tag="v0.12.0")
    version("0.10.0", tag="v0.10.0")

    depends_on("rust@1.64.0:", type="build")
    depends_on("cmake", type="build")

    # cfitsio > 4 introduces a breaking change, is incompatible with mwalib.
    # curl is needed because cfitsio does not --disable-curl by default
    depends_on("cfitsio@3.49")
    depends_on("curl")
    
    depends_on("aoflagger@3.2.0:")
    depends_on("erfa") # because of Marlu

    test_requires_compiler = True

    def setup_build_environment(self, env):
        build_dir = self.stage.source_path
        env.set('CARGO_HOME', f"{build_dir}/.cargo")

    def get_features(self):
        features = ["cfitsio-static"]
        return features

    def install(self, spec, prefix):
        cargo = Executable("cargo")
        # cargo("generate-lockfile")
        features = self.get_features()
        cargo("install", "--path=.", f"--root={prefix}", f"--features={','.join(features)}", "--locked")

    @run_after("install")
    @on_package_attributes(run_tests=True)
    def cargo_test(self):
        cargo = Executable("cargo")
        features = self.get_features()
        cargo("test", "--release", "--lib", f"--features={','.join(features)}")

# test me on setonix with
"""
salloc --nodes=1 --partition=gpu-highmem --account=pawsey0875-gpu -t 00:30:00 --gres=gpu:1

module load spack/default

spack install --test=root --reuse birli@main
spack load birli@main
"""
