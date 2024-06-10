from spack.patch import apply_patch
import os

PATCHFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "as.patch")


class Aoflagger(CMakePackage):
    """RFI detector and quality analysis
    for astronomical radio observations."""

    maintainers("dipietrantonio")

    version('3.4.0', git='https://gitlab.com/aroffringa/aoflagger.git', tag='v3.4.0', submodules=True)
    version('3.2.0', git='https://gitlab.com/aroffringa/aoflagger.git', tag='v3.2.0', submodules=True)

    depends_on('casacore@3.2.1:')
    depends_on('fftw@3.3.8:')
    depends_on('boost@1.80.0: +test +date_time')
    depends_on('libxml2')
    depends_on('cfitsio')
    depends_on('libpng')
    depends_on('hdf5@1.10.7 +cxx ~mpi api=v110')
    depends_on('lua@5.2:')
    depends_on('cmake', type='build')

    patch('as.patch', when='@3.2.0')
