# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Pawsey: Added version 2.4.1.4 with CUDA 13 support for setonix-q.

import os
import platform

from spack.package import *

_versions = {
    # cuTensor 1.5.0
    "1.5.0.3": {
        "Linux-x86_64": "4fdebe94f0ba3933a422cff3dd05a0ef7a18552ca274dd12564056993f55471d",
        "Linux-ppc64le": "ad736acc94e88673b04a3156d7d3a408937cac32d083acdfbd8435582cbe15db",
        "Linux-aarch64": "5b9ac479b1dadaf40464ff3076e45f2ec92581c07df1258a155b5bcd142f6090",
    },
    "2.0.1.2": {
        "Linux-x86_64": "ededa12ca622baad706ea0a500a358ea51146535466afabd96e558265dc586a2",
        "Linux-ppc64le": "7176083a4dad44cb0176771be6efb3775748ad30a39292bf7b4584510f1dd811",
        "Linux-aarch64": "4214a0f7b44747c738f2b643be06b2b24826bd1bae6af27f29f3c6dec131bdeb",
    },
    # cuTensor 2.4.1 built for CUDA 13
    "2.4.1.4": {
        "Linux-x86_64": "032904fb8bba341e24aa45a8cc7b5afc63e4c28e22474530ccc97cfa546d0442",
        "Linux-aarch64": "9baffd3658b7f4da2d2f94d23c3acddb6d12c62997d3da39a774a058fef04aa5",
    },
}


class Cutensor(Package):
    """NVIDIA cuTENSOR Library is a GPU-accelerated tensor linear algebra
    library providing tensor contraction, reduction and elementwise
    operations."""

    homepage = "https://developer.nvidia.com/cutensor"

    maintainers("bvanessen")
    url = "cutensor"

    skip_version_audit = ["platform=darwin", "platform=windows"]

    for ver, packages in _versions.items():
        key = "{0}-{1}".format(platform.system(), platform.machine())
        pkg = packages.get(key)
        if pkg:
            version(ver, sha256=pkg)

    # CUDA version requirements
    depends_on("cuda@11.0:", when="@1.5.0.3", type=("build", "link", "run"))
    depends_on("cuda@11.0:", when="@2.0.1.2", type=("build", "link", "run"))
    depends_on("cuda@13.0.0:13.0.999", when="@2.4.1.4", type=("build", "link", "run"))

    def url_for_version(self, version):
        # Get the system and machine arch for building the file path
        sys = "{0}-{1}".format(platform.system(), platform.machine())
        # Munge it to match Nvidia's naming scheme
        sys_key = sys.lower()
        sys_key = sys_key.replace("aarch64", "sbsa")

        # cuTensor 2.4+ uses different URL format with CUDA-version suffixes
        ver_str = str(version)
        if ver_str.startswith("2.4"):
            url = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/{0}/libcutensor-{0}-{1}_cuda13-archive.tar.xz"
        else:
            url = "https://developer.download.nvidia.com/compute/cutensor/redist/libcutensor/{0}/libcutensor-{0}-{1}-archive.tar.xz"
        return url.format(sys_key, version)

    def install(self, spec, prefix):
        install_tree(".", prefix)

    def _setup_root_environment(self, env):
        env.set("CUTENSOR_ROOT", self.prefix)
        env.set("CUTENSOR_DIR", self.prefix)

        env.prepend_path("C_INCLUDE_PATH", self.prefix.include)
        env.prepend_path("CPLUS_INCLUDE_PATH", self.prefix.include)

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
