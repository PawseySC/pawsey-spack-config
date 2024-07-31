from spack.package import *

class Hyperdrive(Package, ROCmPackage, CudaPackage):
    """A preprocessing pipeline for the Murchison Widefield Array"""

    homepage = "https://github.com/MWATelescope/mwa_hyperdrive"
    git = "https://github.com/MWATelescope/mwa_hyperdrive.git"

    maintainers = ["d3v-null"]

    version("main",  branch="main")
    version("0.4.1", tag="v0.4.1")

    variant("plotting", default=True, description="Enable plotting subcommands like plot-solutions")

    depends_on("rust@1.68.0:", type="build")
    depends_on("cfitsio@3.49")
    depends_on("aoflagger@3.2.0:") # because of Birli
    depends_on("erfa") # because of Marlu
    depends_on("hdf5@1.10: +cxx ~mpi api=v110")
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
            print(f"rocm_dir: {rocm_dir}, amdgpu_target: {amdgpu_target}")
            if hip_spec.satisfies("@6:"):
                env.set('HIP_PATH', rocm_dir)
            else:
                env.set('HIP_PATH', rocm_dir)
                env.set('ROCM_PATH', rocm_dir)
        if self.spec.satisfies("+cuda"):
            cuda_arch = spec.variants["cuda_arch"].value
            env.set('HYPERDRIVE_CUDA_COMPUTE', cuda_arch)
            cuda_dir = self.spec["cuda"].prefix
            print(f"cuda_dir: {cuda_dir}, cuda_arch: {cuda_arch}")

    def get_features(self):
        features = ["cfitsio-static", "hdf5-static"]
        if self.spec.satisfies("+rocm"):
            features += ["hip"]
        if self.spec.satisfies("+cuda"):
            features += ["cuda"]
        if self.spec.satisfies('+plotting'):
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

# test me on setonix with
"""
salloc --nodes=1 --partition=gpu-highmem --account=pawsey0875-gpu -t 00:30:00 --gres=gpu:1

module load spack/default

spack install --test=root --reuse hyperdrive@main amdgpu_target=gfx90a +rocm
spack module lmod refresh
module use $MYSOFTWARE/setonix/2024.05/modules/zen3/gcc/12.2.0
eval $(spack module lmod loads 'hyperdrive@main' | grep -v '#')

# this works too:
# spack env activate --temp -p
# spack add hyperdrive@main amdgpu_target=gfx90a +rocm
# spack install --test=root --reuse

# catch undefined variables
( set -u; echo MYSOFTWARE: $MYSOFTWARE$'\n'MYSCRATCH: $MYSCRATCH )

# Astro stuff
export obsid=1087251016
export outdir="${MYSCRATCH}/${obsid}"
mkdir -p $outdir
export metafits="${outdir}/${obsid}.metafits"
[ -f "$metafits" ] || wget -O "$metafits" $'http://ws.mwatelescope.org/metadata/fits?obs_id='${obsid}
export srclist=${outdir}/srclist_pumav3_EoR0LoBES_EoR1pietro_CenA-GP_2023-11-07.fits
if [[ $srclist =~ srclist_puma && ! -f "$srclist" ]]; then
    wget -O $srclist "https://github.com/JLBLine/srclists/raw/master/${srclist##*/}"
fi
export MWA_BEAM_FILE="${MWA_BEAM_FILE:=$MYSOFTWARE/mwa_full_embedded_element_pattern.h5}"
[ -f $MWA_BEAM_FILE ] || wget -O "$MWA_BEAM_FILE" $'http://ws.mwatelescope.org/static/mwa_full_embedded_element_pattern.h5'
export hyp_toml="${outdir}/hyp_conf.toml"
cat >$hyp_toml <<EOF
[beam]
# uncomment to make segfaults magically disappear before your very eyes!
# no_beam = true
unity_dipole_gains = false

[model]
no_precession = false
cpu = false

[sky-model]
source_list = "$srclist"
num_sources = 1

[vis-simulate]
metafits = "$metafits"
filter_points = false
filter_gaussians = false
filter_shapelets = false
num_timesteps = 1
ignore_dut1 = false
num_fine_channels = 1
middle_freq = 200000000.0
freq_res =      1280000.0
EOF

hyperdrive vis-simulate -vvv -- "$hyp_toml" | tee "hyp_vis-sim.log"
"""