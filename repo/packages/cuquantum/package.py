# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Pawsey: Added NVIDIA cuQuantum SDK 25.11.1 with CUDA 13 support for setonix-q.

import os
import platform

from spack.package import *


_versions = {
    "25.11.1": {
        "archive_version": "25.11.1.11",
        "cuda_version": "13",
        "Linux-x86_64": (
            "dfc063a88547636b316b9682a6834c5fbd2dfd7e823c5fc58857c4251d2ab3c2"
        ),
        "Linux-aarch64": (
            "14a44b09d384c27dd36eae9d9858c90140e6422bbd80bda1041ded96ec3c7223"
        ),
    },
}


class Cuquantum(Package):
    """NVIDIA cuQuantum SDK provides GPU-accelerated libraries for quantum
    circuit simulation, tensor-network contraction, and related workflows."""

    homepage = "https://developer.nvidia.com/cuquantum-sdk"
    url = "cuquantum"

    skip_version_audit = ["platform=darwin", "platform=windows"]

    for ver, packages in _versions.items():
        key = "{0}-{1}".format(platform.system(), platform.machine())
        pkg = packages.get(key)
        if pkg:
            version(ver, sha256=pkg)

    variant(
        "mpi",
        default=True,
        description="Build cuTensorNet MPI distributed interface",
    )

    depends_on("c", type="build", when="+mpi")
    depends_on(
        "cuda@13.0.0:13.0.999",
        type=("build", "link", "run"),
        when="@25.11.1",
    )
    depends_on(
        "cutensor@2.4.1.4",
        type=("build", "link", "run"),
        when="@25.11.1",
    )
    depends_on("mpi", type=("build", "link", "run"), when="+mpi")

    def url_for_version(self, version):
        sys_key = "{0}-{1}".format(platform.system(), platform.machine()).lower()
        sys_key = sys_key.replace("aarch64", "sbsa")

        version_data = _versions[str(version)]
        archive_version = version_data["archive_version"]
        cuda_version = version_data["cuda_version"]

        url = (
            "https://developer.download.nvidia.com/compute/cuquantum/redist/"
            "cuquantum/{0}/cuquantum-{0}-{1}_cuda{2}-archive.tar.xz"
        )
        return url.format(sys_key, archive_version, cuda_version)

    def install(self, spec, prefix):
        if "+mpi" in spec:
            self._build_cutensornet_mpi_interface(spec)

        install_tree(".", prefix)

    def _build_cutensornet_mpi_interface(self, spec):
        interface_dir = join_path(self.stage.source_path, "distributed_interfaces")
        source = join_path(interface_dir, "cutensornet_distributed_interface_mpi.c")
        output = join_path(interface_dir, "libcutensornet_distributed_interface_mpi.so")

        if not os.path.isfile(source):
            raise InstallError(
                "cuTensorNet MPI interface source not found: {0}".format(source)
            )

        mpi_cc = Executable(spec["mpi"].mpicc)
        with working_dir(interface_dir):
            mpi_cc(
                "-shared",
                "-std=c99",
                "-fPIC",
                "-I{0}".format(spec["cuda"].prefix.include),
                "-I{0}".format(join_path(self.stage.source_path, "include")),
                source,
                "-o",
                output,
            )

    @property
    def _distributed_interfaces(self):
        return join_path(self.prefix, "distributed_interfaces")

    @property
    def _cutensornet_mpi_lib(self):
        return join_path(
            self._distributed_interfaces,
            "libcutensornet_distributed_interface_mpi.so",
        )

    def _setup_root_environment(self, env):
        env.set("CUQUANTUM_ROOT", self.prefix)
        env.set("CUQUANTUM_DIR", self.prefix)
        env.set("CUSTATEVEC_ROOT", self.prefix)
        env.set("CUTENSORNET_ROOT", self.prefix)

        env.prepend_path("C_INCLUDE_PATH", self.prefix.include)
        env.prepend_path("CPLUS_INCLUDE_PATH", self.prefix.include)

        if os.path.isfile(self._cutensornet_mpi_lib):
            env.set("CUTENSORNET_COMM_LIB", self._cutensornet_mpi_lib)
            env.prepend_path("LIBRARY_PATH", self._distributed_interfaces)
            env.prepend_path("LD_LIBRARY_PATH", self._distributed_interfaces)

        pkgconfig = join_path(self.prefix.lib, "pkgconfig")
        if os.path.isdir(pkgconfig):
            env.prepend_path("PKG_CONFIG_PATH", pkgconfig)

    def setup_run_environment(self, env):
        self._setup_root_environment(env)

    def setup_dependent_build_environment(self, env, dependent_spec):
        self._setup_root_environment(env)
        env.prepend_path("LIBRARY_PATH", self.prefix.lib)
        env.prepend_path("LD_LIBRARY_PATH", self.prefix.lib)
        env.prepend_path("CPATH", self.prefix.include)
        env.prepend_path("CMAKE_PREFIX_PATH", self.prefix)
