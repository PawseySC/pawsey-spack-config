from spack.package import *

class Chips(MakefilePackage):

    homepage = "https://github.com/cathryntrott/chips2024"
    # git = "https://github.com/cathryntrott/chips2024.git"
    git = "https://github.com/d3v-null/chips2024.git"

    maintainers('d3v-null')

    version("main", branch="main")

    depends_on('cfitsio')
    depends_on('openblas')
    depends_on('fftw')
    depends_on('pal')
    depends_on('gsl')
    depends_on("gmake", type="build")

    def install(self, spec, prefix):
        make("install", "PREFIX={0}".format(prefix))

# example
"""
spack install --reuse chips
spack load chips
wget 'https://projects.pawsey.org.au/high0.uvfits/hyp_1061316544_ionosub_ssins_30l_src8k_300it_8s_80kHz_i1000.uvfits'
export DATADIR="$PWD" INPUTDIR="$PWD/" OUTPUTDIR="$PWD/" OBSDIR="$PWD/" OMP_NUM_THREADS="$(nproc)"
export obsid=1061316544 ext=1061316544 eorband=1 eorfield=0
export uvfits=hyp_1061316544_ionosub_ssins_30l_src8k_300it_8s_80kHz_i1000.uvfits
export bias_mode=0 n_chan=384 lowerfreq=166995000 # for bias_mode=0
# export bias_mode=10 n_chan=192 lowerfreq=182515000 # for bias_mode=10
gridvisdiff $uvfits $obsid $ext $eorband -f $eorfield
export freq_idx_start=0 period=8.0 chanwidth=80000 umax=300 nbins=80
export pol=xx
# for pol in xx yy; do
prepare_diff $ext $n_chan $freq_idx_start $pol $ext $eorband -p $period -c $chanwidth -n $lowerfreq -u $umax
lssa_fg_simple $ext $n_chan $nbins $pol $umax $ext $bias_mode $eorband
"""
