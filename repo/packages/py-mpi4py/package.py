# Copyright Spack Project Developers.
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
#
# Pawsey: Added +gtl variant for GPU Transport Layer support (GPU-aware MPI).
#         Enables linking against libmpi_gtl_cuda (NVIDIA) or libmpi_gtl_hsa (AMD).
#         Usage:
#           py-mpi4py +gtl gtl_backend=cuda gtl_lib_path=/path/to/gtl/lib
#
# Notes:
# - This recipe assumes mpi4py will discover mpi.cfg in the project root (source tree).
# - The +gtl logic generates mpi.cfg with:
#     - libraries = mpi_gtl_{cuda,hsa} [+ cudart for cuda]
#     - library_dirs includes MPI lib dirs + GTL dir + (CUDA lib dirs if cuda backend)
#     - runtime_library_dirs includes GTL dir (+ CUDA lib dirs if cuda backend)
# - It validates GTL library existence, supports gtl_lib_path=auto detection, and
#   prints mpi.cfg before install for debugging.
#
# Important: On some MPI stacks, you may need "libraries = mpi mpi_gtl_cuda cudart"
#            instead of "mpi_gtl_cuda cudart". See comment in create_mpi_config_file.

import os

from spack.package import *
from spack.util.environment import EnvironmentModifications
from llnl.util.tty import warn


class PyMpi4py(PythonPackage):
    """This package provides Python bindings for the Message Passing
    Interface (MPI) standard. It is implemented on top of the
    MPI-1/MPI-2 specification and exposes an API which grounds on the
    standard MPI-2 C++ bindings.
    """

    pypi = "mpi4py/mpi4py-3.0.3.tar.gz"
    git = "https://github.com/mpi4py/mpi4py.git"

    license("BSD-3-Clause", when="@4:")
    license("BSD-2-Clause", when="@:3")

    version("master", branch="master")
    version("4.1.1", sha256="eb2c8489bdbc47fdc6b26ca7576e927a11b070b6de196a443132766b3d0a2a22")
    version("4.1.0", sha256="817492796bce771ccd809a6051cf68d48689815493b567a696ce7679260449cd")
    version("4.0.3", sha256="de2710d73e25e115865a3ab63d34a54b2d8608b724f761c567b6ad58dd475609")
    version("4.0.2", sha256="86085436d3ea3587323321b9e661e4df60eabbcf11c2c9cf63d0873ca111cc8b")
    version("4.0.1", sha256="f3174b245775d556f4fddb32519a2066ef0592edc810c5b5a59238f9a0a40c89")
    version("4.0.0", sha256="820d31ae184d69c17d9b5d55b1d524d56be47d2e6cb318ea4f3e7007feff2ccc")
    version("3.1.6", sha256="c8fa625e0f92b082ef955bfb52f19fa6691d29273d7d71135d295aa143dee6cb")
    version("3.1.5", sha256="a706e76db9255135c2fb5d1ef54cb4f7b0e4ad9e33cbada7de27626205f2a153")
    version("3.1.4", sha256="17858f2ebc623220d0120d1fa8d428d033dde749c4bc35b33d81a66ad7f93480")
    version("3.1.3", sha256="f1e9fae1079f43eafdd9f817cdb3fd30d709edc093b5d5dada57a461b2db3008")
    version("3.1.2", sha256="40dd546bece8f63e1131c3ceaa7c18f8e8e93191a762cd446a8cfcf7f9cce770")
    version("3.1.1", sha256="e11f8587a3b93bb24c8526addec664b586b965d83c0882b884c14dc3fd6b9f5c")
    version("3.1.0", sha256="134fa2b2fe6d8f91bcfcc2824cfd74b55ca3dcbff4d185b1bda009beea9232ec")
    version("3.0.3", sha256="012d716c8b9ed1e513fcc4b18e5af16a8791f51e6d1716baccf988ad355c5a1f")
    version("3.0.1", sha256="6549a5b81931303baf6600fa2e3bc04d8bd1d5c82f3c21379d0d64a9abcca851")
    version("3.0.0", sha256="b457b02d85bdd9a4775a097fac5234a20397b43e073f14d9e29b6cd78c68efd7")
    version("2.0.0", sha256="6543a05851a7aa1e6d165e673d422ba24e45c41e4221f0993fe1e5924a00cb81")
    version("1.3.1", sha256="e7bd2044aaac5a6ea87a87b2ecc73b310bb6efe5026031e33067ea3c2efc3507")

    depends_on("c", type="build")
    depends_on("cxx", type="build")

    depends_on("py-setuptools@40.9:", type="build")
    depends_on("py-cython@3:", when="@4:", type="build")
    depends_on("py-cython@0.27:2", when="@:3.1.6", type="build")
    depends_on("py-cython@0.27:3", when="@master", type="build")

    depends_on("mpi")

    depends_on("cuda", when="+gtl gtl_backend=cuda")

    variant(
        "gtl",
        default=False,
        description="Enable GPU Transport Layer for GPU-aware MPI communication",
    )
    variant(
        "gtl_backend",
        default="cuda",
        values=("cuda", "hsa"),
        description="GTL backend: cuda for NVIDIA GPUs, hsa for AMD GPUs",
        when="+gtl",
    )
    variant(
        "gtl_lib_path",
        default="auto",
        values=str,
        description="Path to GTL library directory (or 'auto' to detect from MPI libs)",
        when="+gtl",
    )

    # GTL requires mpi4py 4.0+ for mpi.cfg support
    conflicts("+gtl", when="@:3", msg="Building with GTL support requires mpi4py 4.0 or later")

    @staticmethod
    def _pathlist(x):
        """Convert list/tuple/None/str -> os.pathsep-separated string."""
        if not x:
            return ""
        if isinstance(x, (list, tuple)):
            return os.pathsep.join(str(p) for p in x if p)
        return str(x)

    def _gtl_soname(self):
        backend = self.spec.variants["gtl_backend"].value
        return "libmpi_gtl_cuda.so" if backend == "cuda" else "libmpi_gtl_hsa.so"

    def _gtl_libname(self):
        backend = self.spec.variants["gtl_backend"].value
        return "mpi_gtl_cuda" if backend == "cuda" else "mpi_gtl_hsa"

    def _detect_gtl_dir(self):
        """Try to locate the GTL .so in reasonable locations."""
        mpi_spec = self.spec["mpi"]
        candidates = []

        gtl_path = self.spec.variants["gtl_lib_path"].value
        if gtl_path and gtl_path not in ("auto", "", None):
            candidates.append(gtl_path)

        try:
            candidates.extend(list(mpi_spec.libs.directories))
        except Exception:
            pass

        candidates.extend(
            [
                join_path(mpi_spec.prefix, "lib"),
                join_path(mpi_spec.prefix, "lib64"),
            ]
        )

        soname = self._gtl_soname()
        for d in candidates:
            if d and os.path.isfile(join_path(d, soname)):
                return d
        return None

    def setup_build_environment(self, env: EnvironmentModifications) -> None:
        # Always build with the MPI wrapper from the dependency (Spack-managed).
        env.set("MPICC", self.spec["mpi"].mpicc)

        if "+gtl" in self.spec:
            # Matches the manual build approach for MPICH
            env.set("MPICH_GPU_SUPPORT_ENABLED", "1")
            # Useful for diagnosing what link flags are used
            env.set("MPI4PY_BUILD_VERBOSE", "1")

    def setup_run_environment(self, env: EnvironmentModifications) -> None:
        if "+gtl" in self.spec:
            env.set("MPICH_GPU_SUPPORT_ENABLED", "1")

    @run_before("install")
    def validate_gtl_path(self):
        """Validate GTL library path exists when +gtl is enabled (or auto-detect it)."""
        if "+gtl" not in self.spec:
            return

        gtl_dir = self._detect_gtl_dir()
        if not gtl_dir:
            soname = self._gtl_soname()
            raise InstallError(
                "Could not locate GTL library ({0}). "
                "Set gtl_lib_path explicitly, e.g.\n"
                "  py-mpi4py +gtl gtl_backend=cuda gtl_lib_path=/opt/cray/pe/mpich/.../lib".format(soname)
            )

        self._resolved_gtl_dir = gtl_dir  # noqa: B010
        warn(f"[mpi4py +gtl] resolved GTL dir = {gtl_dir}")

        expected_lib = join_path(gtl_dir, self._gtl_soname())
        if not os.path.isfile(expected_lib):
            raise InstallError(
                "GTL library not found at {0}. "
                "Verify gtl_lib_path points to a directory containing {1}".format(expected_lib, self._gtl_soname())
            )

    @run_before("install")
    def write_and_dump_mpi_cfg_for_install(self):
        """Generate mpi.cfg in the source tree so the install picks it up; dump for debug."""
        cfg_fn = join_path(self.stage.source_path, "mpi.cfg")
        self.create_mpi_config_file(cfg_fn)

        warn("===== mpi.cfg (debug) =====")
        warn(open(cfg_fn, "r").read())
        warn("===== end mpi.cfg =====")

    @run_before("install")
    def cythonize(self):
        with working_dir(self.build_directory):
            python(join_path("conf", "cythonize.py"))

    def create_mpi_config_file(self, cfg_fn):
        """
        Create mpi.cfg file introduced since version 4.0.0.
        """
        mpi_spec = self.spec["mpi"]
        backend = self.spec.variants["gtl_backend"].value

        include_dirs = self._pathlist(mpi_spec.headers.directories)
        mpi_libdirs = self._pathlist(mpi_spec.libs.directories)

        gtl_library = None
        gtl_dir = None
        if "+gtl" in self.spec:
            gtl_library = self._gtl_libname()
            gtl_dir = getattr(self, "_resolved_gtl_dir", None) or self._detect_gtl_dir()

        cuda_libdirs = ""
        if "+gtl" in self.spec and backend == "cuda":
            cuda_libdirs = self._pathlist(self.spec["cuda"].libs.directories)

        libs = []
        if gtl_library:
            libs.append(gtl_library)
            if backend == "cuda":
                libs.append("cudart")

        libdirs = []
        if mpi_libdirs:
            libdirs.append(mpi_libdirs)
        if gtl_dir:
            libdirs.append(gtl_dir)
        if cuda_libdirs:
            libdirs.append(cuda_libdirs)

        library_dirs = os.pathsep.join([d for d in libdirs if d])

        rdirs = []
        if gtl_dir:
            rdirs.append(gtl_dir)
        if cuda_libdirs:
            rdirs.append(cuda_libdirs)

        runtime_dirs = os.pathsep.join([d for d in rdirs if d])

        with open(cfg_fn, "w") as cfg:
            cfg.write("[mpi]\n")
            cfg.write("mpi_dir              = {0}\n".format(mpi_spec.prefix))
            cfg.write("mpicc                = {0}\n".format(mpi_spec.mpicc))
            cfg.write("mpicxx               = {0}\n".format(mpi_spec.mpicxx))
            cfg.write("\n")

            cfg.write("## define_macros        =\n")
            cfg.write("## undef_macros         =\n")

            if include_dirs:
                cfg.write("include_dirs         = {0}\n".format(include_dirs))
            else:
                cfg.write("## include_dirs         =\n")

            if libs:
                cfg.write("libraries            = {0}\n".format(" ".join(libs)))
            else:
                cfg.write("## libraries            = mpi\n")

            if library_dirs:
                cfg.write("library_dirs         = {0}\n".format(library_dirs))
            else:
                cfg.write("## library_dirs         = %(mpi_dir)s/lib\n")

            if runtime_dirs:
                cfg.write("runtime_library_dirs = {0}\n".format(runtime_dirs))
            else:
                cfg.write("## runtime_library_dirs = %(mpi_dir)s/lib\n")

            cfg.write("\n")
            cfg.write("## extra_compile_args   =\n")
            cfg.write("## extra_link_args      =\n")
            cfg.write("## extra_objects        =\n")

    @run_after("install", when="@4:")
    def install_cfg(self):
        python_dir = join_path(self.prefix, python_platlib, "mpi4py")
        cfg_fn = join_path(python_dir, "mpi.cfg")
        staged_cfg = join_path(self.stage.source_path, "mpi.cfg")
        if os.path.isfile(staged_cfg):
            mkdirp(python_dir)
            copy(staged_cfg, cfg_fn)
        else:
            self.create_mpi_config_file(cfg_fn)