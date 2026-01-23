# Copyright 2013-2026 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
import glob

from spack.package import *


class PyCudaPython(PythonPackage):
    """CUDA Python: Performance meets Productivity.

    NOTE (simplified packaging):
    NVIDIA's cuda-python repo is a monorepo containing multiple Python distributions
    (cuda-python, cuda-bindings, cuda-pathfinder, and sometimes additional CUDA component
    packages). For simplicity, this Spack package installs the required subprojects
    into a single prefix so downstream packages (e.g. nvmath-python) can import
    cuda.bindings.* modules.
    """

    homepage = "https://nvidia.github.io/cuda-python/"
    url = "https://github.com/NVIDIA/cuda-python/archive/refs/tags/v13.1.0.tar.gz"
    git = "https://github.com/NVIDIA/cuda-python.git"

    maintainers("nvidia")

    license("LicenseRef-NVIDIA-SOFTWARE-LICENSE")

    # Version 13.x releases
    version(
        "13.1.0",
        sha256="63cc2823bb73bfe1e7e697457364d626f8e7705d6c3dc93a7d120dd788e2a93e",
        preferred=True,
    )
    version("13.0.0", sha256="606bb3202392eb1014c82023e44858dbdd13a6ad7e4529251a12e72c76c7171f")

    # Version 12.x releases
    version("12.6.1", sha256="07ce07b02e726f59dc2cd333d3b195df960ecfa4fbe47bbfdbb2541f7485c3d6")
    version("12.9.5", sha256="c7aa5390faad675db7af568bda48607888f3ce987aa9c463f95c5e33f4f04a3b")
    version("12.9.4", sha256="3e95a80d5e1fea864dd55f7600f9e5c9af6e42866ae15206e386338649efea13")
    version("12.9.3", sha256="8390a57c4f030fcd0557e02c3f6dc32e676413ae87f409630fa280ad05c218a7")
    version("12.9.2", sha256="14ed346e848f796929516ebce1e3b33567c4f285abf44aa767ec8e9542ca6a68")

    def url_for_version(self, version):
        return "https://github.com/NVIDIA/cuda-python/archive/refs/tags/v{0}.tar.gz".format(version)

    # Python requirements
    depends_on("python@3.10:", type=("build", "run"))

    # Build deps (covers typical pyproject builds)
    depends_on("py-pip", type="build")
    depends_on("py-setuptools@80:", type="build")
    depends_on("py-setuptools-scm@8:", type="build")
    depends_on("py-packaging@24.2:", type="build")
    depends_on("py-pyclibrary", type="build")
    depends_on("py-wheel", type="build")
    depends_on("py-cython", type="build")

    # CUDA toolkit for building bindings
    # (Package version != CUDA version; this is a conservative, practical mapping.)
    depends_on("cuda@11.8:", when="@12:", type=("build", "link", "run"))
    depends_on("cuda@12:", when="@13:", type=("build", "link", "run"))

    variant("all", default=False, description="Install all CUDA Python component subpackages found in the repo")
    
    def setup_build_environment(self, env):
        if self.spec.satisfies("^cuda"):
            cuda = self.spec["cuda"].prefix
    
            env.set("CUDA_HOME", str(cuda))
            env.set("CUDA_PATH", str(cuda))
    
            # Headers
            env.prepend_path("CPATH", cuda.include)
            env.prepend_path("C_INCLUDE_PATH", cuda.include)
            env.prepend_path("CPLUS_INCLUDE_PATH", cuda.include)
    
            # Libraries
            env.prepend_path("LIBRARY_PATH", cuda.lib64)
            env.prepend_path("LD_LIBRARY_PATH", cuda.lib64)
    
            # Stub driver libs (common fix for NVML link on build nodes)
            stubs = cuda.join("lib64/stubs")  # single string!
            if os.path.isdir(stubs):
                env.prepend_path("LIBRARY_PATH", stubs)
                env.prepend_path("LD_LIBRARY_PATH", stubs)
    

    def _is_python_dist_dir(self, path):
        """Heuristic: treat a directory as a Python dist if it contains a build descriptor."""
        return os.path.isdir(path) and (
            os.path.exists(os.path.join(path, "pyproject.toml"))
            or os.path.exists(os.path.join(path, "setup.py"))
            or os.path.exists(os.path.join(path, "setup.cfg"))
        )

    def _find_repo_subdists(self):
        """Return candidate subproject dirs in install order."""
        # Minimum set that fixes "missing cython files"/cuda.bindings.* imports.
        required = ["cuda_bindings", "cuda_pathfinder", "cuda_python"]

        # Always install required ones if present.
        dists = []
        for d in required:
            p = os.path.join(self.stage.source_path, d)
            if self._is_python_dist_dir(p):
                dists.append(p)

        # Optionally install all other cuda_* sub-dists found (excluding the required ones already).
        if "+all" in self.spec:
            for p in sorted(glob.glob(os.path.join(self.stage.source_path, "cuda_*"))):
                if os.path.abspath(p) in map(os.path.abspath, dists):
                    continue
                # Skip obvious non-dists (docs, scripts, etc.) while being robust.
                base = os.path.basename(p)
                if base in ("cuda_bindings", "cuda_pathfinder", "cuda_python"):
                    continue
                if self._is_python_dist_dir(p):
                    dists.append(p)

        return dists

    @run_after("install")
    def _post_install_sanity(self):
        # Basic import check: cuda.bindings should exist after install
        python("-c", "import cuda; import cuda.bindings; import cuda.bindings.cydriver")

    def install(self, spec, prefix):
        # Install multiple Python distributions from the monorepo into this one prefix.
        # We use --no-deps because Spack controls dependencies.
        dists = self._find_repo_subdists()

        if not dists:
            raise InstallError(
                "No installable Python subprojects were found in the cuda-python source tree."
            )

        for dist in dists:
            with working_dir(dist):
                pip(
                    "install",
                    "--no-deps",
                    "--no-build-isolation",
                    "--prefix={0}".format(prefix),
                    ".",
                )
