from spack.package import *

class PyNumbaCuda(PythonPackage):
    """
    Numba-CUDA: Python bindings for CUDA, enabling GPU programming with Numba.
    """
    homepage = "https://github.com/numba/numba-cuda"
    pypi = "numba_cuda/numba_cuda-0.24.0.tar.gz"

    version("0.24.0", sha256="f15a11a8d224e160e9cb2345049c5fa0bbd49eb255b2e8f661086746a7feb378")
    # Alias for environments requesting 0.24; maps to 0.24.0 tarball
    version("0.24", sha256="f15a11a8d224e160e9cb2345049c5fa0bbd49eb255b2e8f661086746a7feb378", deprecated=True)

    depends_on('python@3.7:', type=('build', 'run'))
    depends_on('py-setuptools', type='build')
    depends_on('py-numba', type=('build', 'run'))
    depends_on('cuda')

    def setup_build_environment(self, env):
        # Set CUDA_HOME and CUDA_PATH for builds using CUDA
        if self.spec.satisfies("^cuda"):
            env.set("CUDA_HOME", self.spec["cuda"].prefix)
            env.set("CUDA_PATH", self.spec["cuda"].prefix)

    def url_for_version(self, version):
        """Map 0.24 alias to 0.24.0 source tarball."""
        fname_ver = "0.24.0" if version == Version("0.24") else str(version)
        return f"https://files.pythonhosted.org/packages/source/n/numba_cuda/numba_cuda-{fname_ver}.tar.gz"
