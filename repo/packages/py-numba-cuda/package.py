from spack.package import *

class NumbaCuda(PythonPackage):
    """
    Numba-CUDA: Python bindings for CUDA, enabling GPU programming with Numba.
    """
    homepage = "https://github.com/numba/numba-cuda"
    pypi = "numba-cuda/numba-cuda-0.24.tar.gz"

    version('0.24', sha256='0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5')

    depends_on('python@3.7:', type=('build', 'run'))
    depends_on('py-setuptools', type='build')
    depends_on('py-numba', type=('build', 'run'))
    depends_on('cuda')

    def setup_build_environment(self, env):
        # Set CUDA_HOME and CUDA_PATH for builds using CUDA
        if self.spec.satisfies("^cuda"):
            env.set("CUDA_HOME", self.spec["cuda"].prefix)
            env.set("CUDA_PATH", self.spec["cuda"].prefix)
