# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Pawsey-developed recipe for Qiskit plus locally built Qiskit Aer with CUDA
# and cuQuantum support on setonix-q.

import glob
import os
import shutil

from spack.package import *


_aer_versions = {
    "1.4.5": "0.17.1",
    "2.3.0": "0.17.2",
}


class PyQiskit(PythonPackage, CudaPackage):
    """Qiskit with a locally built CUDA/cuQuantum Qiskit Aer simulator."""

    homepage = "https://www.ibm.com/quantum/qiskit"
    url = "https://files.pythonhosted.org/packages/07/6c/6b8b35f67159401580665c59ae64d676bef9e85aac4d2a50831cbe32f652/qiskit_aer-0.17.2.tar.gz"

    license("Apache-2.0")

    version(
        "2.3.0",
        sha256="134eef8e509311955a15be543d2ba368f988f3583a2bc1f548af3196da820eb4",
        preferred=True,
    )
    version("1.4.5", sha256="4de47d5a23e283e6cea44186002ab296212c4d837705c528818fbb6cfd28c185")

    resource(
        name="qiskit-wheel",
        url="https://files.pythonhosted.org/packages/d1/c6/d928648d417c5c2e0c50481ef4f197f2ad8ca74d361e163e0c5d73253cbf/qiskit-2.3.0-cp310-abi3-manylinux2014_aarch64.manylinux_2_17_aarch64.whl",
        sha256="b437262a14ab961703153f79f38de5fde408601b0eda1f9c34b57498c912ef33",
        expand=False,
        placement={
            "qiskit-2.3.0-cp310-abi3-manylinux2014_aarch64.manylinux_2_17_aarch64.whl": (
                "qiskit-2.3.0-cp310-abi3-manylinux2014_aarch64.manylinux_2_17_aarch64.whl"
            )
        },
        when="@2.3.0",
    )
    resource(
        name="qiskit-wheel",
        url="https://files.pythonhosted.org/packages/5b/c5/4fee17879dff440fc81b8d1b31e302d1a4d3778c09445c995a860de017d8/qiskit-1.4.5-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl",
        sha256="bed7c45486e624e6b0c7416b0bc46d34d43b1fe0698fdd1f5a820af1dcb2e6f2",
        expand=False,
        placement={
            "qiskit-1.4.5-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl": (
                "qiskit-1.4.5-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
            )
        },
        when="@1.4.5",
    )

    variant("mpi", default=True, description="Build Qiskit Aer with MPI support")

    conflicts("~cuda", msg="This recipe is for the CUDA/cuQuantum Qiskit Aer build")
    conflicts("cuda_arch=none")

    depends_on("c", type="build")
    depends_on("cxx", type="build")
    depends_on("python@3.10:", when="@2:", type=("build", "run"))
    depends_on("python@3.9:", when="@1:", type=("build", "run"))

    depends_on("py-pip", type="build")
    depends_on("py-setuptools@80:", type="build")
    depends_on("py-wheel", type="build")
    depends_on("py-cython", type="build")
    depends_on("py-scikit-build@0.11:", type="build")
    depends_on("py-conan@1.65.0", type="build")
    depends_on("py-pybind11@2.13.4", type="build")
    depends_on("cmake", type="build")
    depends_on("ninja", type="build")

    depends_on("py-rustworkx@0.15:", type=("build", "run"))
    depends_on("py-numpy@1.17:2.999", type=("build", "run"))
    depends_on("py-scipy@1.5:", type=("build", "run"))
    depends_on("py-dill@0.3:", type=("build", "run"))
    depends_on("py-stevedore@3:", type=("build", "run"))
    depends_on("py-typing-extensions", type=("build", "run"))
    depends_on("py-sympy@1.3:", when="@1:", type=("build", "run"))
    depends_on("py-symengine@0.11:0.13", when="@1:", type=("build", "run"))

    depends_on("py-psutil@5:", type=("build", "run"))
    depends_on("py-python-dateutil@2.8:", type=("build", "run"))

    depends_on("cuda@13", type=("build", "link", "run"))
    depends_on("cuquantum@25.11.1:", type=("build", "link", "run"))
    depends_on("cutensor@2.4.1.4:", type=("build", "link", "run"))
    depends_on("mpi", when="+mpi", type=("build", "link", "run"))
    depends_on("py-mpi4py+gtl", when="+mpi", type=("build", "run"))

    def url_for_version(self, version):
        aer_version = _aer_versions[str(version)]
        urls = {
            "0.17.2": "https://files.pythonhosted.org/packages/07/6c/6b8b35f67159401580665c59ae64d676bef9e85aac4d2a50831cbe32f652/qiskit_aer-0.17.2.tar.gz",
            "0.17.1": "https://files.pythonhosted.org/packages/f7/37/40d06dab01752712a8ad903c175f282088f5d92ede2fc558e9b43622ec27/qiskit_aer-0.17.1.tar.gz",
        }
        return urls[aer_version]

    def _cuda_arch(self):
        archs = self.spec.variants["cuda_arch"].value
        if archs == "none":
            return "90"
        return str(archs[0])

    def _aer_cuda_arch(self):
        arch = self._cuda_arch()
        if len(arch) == 2 and arch.isdigit():
            return "{0}.{1}".format(arch[0], arch[1])
        return arch

    def _gtl_lib_path(self):
        if "py-mpi4py" not in self.spec:
            return None

        mpi4py = self.spec["py-mpi4py"]
        if "+gtl" not in mpi4py:
            return None

        gtl_path = mpi4py.variants["gtl_lib_path"].value
        if gtl_path in (None, "", "auto"):
            return None
        return gtl_path

    def patch(self):
        source_file = join_path("src", "simulators", "statevector", "chunk", "thrust_kernels.hpp")
        if not os.path.isfile(source_file):
            raise InstallError("Expected Qiskit Aer source file not found: {0}".format(source_file))

        # CUDA 13's bundled Thrust removed thrust::unary_function. Drop the
        # deprecated base class and provide the argument_type/result_type
        # typedefs the functors actually rely on. These replacements span
        # multiple lines, so they cannot use filter_file (which matches line
        # by line in Spack 0.23.x) and are applied to the whole file instead.
        replacements = [
            (
                "  struct stride_functor\n"
                "      : public thrust::unary_function<difference_type, difference_type> {",
                "  struct stride_functor {\n"
                "    typedef difference_type argument_type;\n"
                "    typedef difference_type result_type;",
            ),
            (
                "struct complex_dot_scan\n"
                "    : public thrust::unary_function<thrust::complex<data_t>,\n"
                "                                    thrust::complex<data_t>> {",
                "struct complex_dot_scan {\n"
                "  typedef thrust::complex<data_t> argument_type;\n"
                "  typedef thrust::complex<data_t> result_type;",
            ),
            (
                "struct complex_norm : public thrust::unary_function<thrust::complex<data_t>,\n"
                "                                                    thrust::complex<data_t>> {",
                "struct complex_norm {\n"
                "  typedef thrust::complex<data_t> argument_type;\n"
                "  typedef thrust::complex<data_t> result_type;",
            ),
        ]

        with open(source_file, encoding="utf-8") as handle:
            content = handle.read()

        for needle, replacement in replacements:
            if needle not in content:
                raise InstallError(
                    "Qiskit Aer thrust patch target not found in {0}".format(source_file)
                )
            content = content.replace(needle, replacement)

        with open(source_file, "w", encoding="utf-8") as handle:
            handle.write(content)

    def setup_build_environment(self, env):
        env.set("CUDAARCHS", self._cuda_arch())
        env.set("AER_CUDA_ARCH", self._aer_cuda_arch())
        env.set("CONAN_USER_HOME", join_path(self.stage.source_path, ".conan"))
        env.set("CMAKE_BUILD_PARALLEL_LEVEL", str(make_jobs))

        if "+mpi" in self.spec:
            env.set("MPICC", self.spec["mpi"].mpicc)
            env.set("MPICXX", self.spec["mpi"].mpicxx)
            env.set("MPICH_GPU_SUPPORT_ENABLED", "1")
            env.set("MPICH_GPU_IPC_ENABLED", "0")

            gtl_path = self._gtl_lib_path()
            if gtl_path:
                env.prepend_path("LD_LIBRARY_PATH", gtl_path)
                env.prepend_path("CRAY_LD_LIBRARY_PATH", gtl_path)

    def setup_run_environment(self, env):
        if "+mpi" in self.spec:
            env.set("MPICH_GPU_SUPPORT_ENABLED", "1")
            env.set("MPICH_GPU_IPC_ENABLED", "0")
            gtl_path = self._gtl_lib_path()
            if gtl_path:
                env.prepend_path("LD_LIBRARY_PATH", gtl_path)
                env.prepend_path("CRAY_LD_LIBRARY_PATH", gtl_path)

    def install(self, spec, prefix):
        qiskit_wheels = glob.glob(join_path(self.stage.source_path, "qiskit-*.whl"))
        if len(qiskit_wheels) != 1:
            raise InstallError("Expected one staged Qiskit wheel, found {0}".format(qiskit_wheels))

        pip("install", "--no-deps", "--prefix={0}".format(prefix), qiskit_wheels[0])

        shutil.rmtree("build", ignore_errors=True)
        shutil.rmtree("dist", ignore_errors=True)
        shutil.rmtree("_skbuild", ignore_errors=True)
        for egg_info in glob.glob("*.egg-info"):
            shutil.rmtree(egg_info, ignore_errors=True)

        cmake_args = [
            "-DAER_THRUST_BACKEND=CUDA",
            "-DAER_CUDA_ARCH={0}".format(self._aer_cuda_arch()),
            "-DCMAKE_CUDA_ARCHITECTURES={0}".format(self._cuda_arch()),
            "-DCMAKE_CXX_STANDARD=17",
            "-DCMAKE_CXX_STANDARD_REQUIRED=ON",
            "-DCMAKE_CUDA_STANDARD=17",
            "-DCMAKE_CUDA_STANDARD_REQUIRED=ON",
            "-DCUQUANTUM_ROOT={0}".format(spec["cuquantum"].prefix),
            "-DCUTENSOR_ROOT={0}".format(spec["cutensor"].prefix),
            "-DAER_MPI={0}".format("True" if "+mpi" in spec else "False"),
            "-DAER_ENABLE_CUQUANTUM=true",
        ]

        gtl_path = self._gtl_lib_path()
        if "+mpi" in spec and gtl_path:
            gtl_flags = "-L{0} -lmpi_gtl_cuda -Wl,-rpath,{0}".format(gtl_path)
            cmake_args.extend(
                [
                    "-DAER_LINKER_FLAGS={0}".format(gtl_flags),
                    "-DCMAKE_SHARED_LINKER_FLAGS={0}".format(gtl_flags),
                    "-DCMAKE_MODULE_LINKER_FLAGS={0}".format(gtl_flags),
                ]
            )

        python("setup.py", "bdist_wheel", "-vvv", "--", *cmake_args, "--")

        aer_wheels = glob.glob(join_path("dist", "qiskit_aer*.whl"))
        if len(aer_wheels) != 1:
            raise InstallError("Expected one Qiskit Aer wheel, found {0}".format(aer_wheels))

        pip("install", "--no-deps", "--prefix={0}".format(prefix), aer_wheels[0])
