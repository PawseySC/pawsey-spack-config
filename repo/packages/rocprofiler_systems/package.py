# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import CMakePackage
from spack.build_environment import EnvironmentModifications

from spack.package import *


class RocprofilerSystems(CMakePackage):
    """Application Profiling, Tracing, and Analysis"""

    homepage = "https://github.com/ROCm/rocprofiler-systems"
    git = "https://github.com/ROCm/rocprofiler-systems.git"
    url = "https://github.com/ROCm/rocprofiler-systems/archive/refs/tags/rocm-6.3.1.tar.gz"

    maintainers("dgaliffiAMD", "afzpatel", "srekolam", "renjithravindrankannath", "wilephan-amd")

    license("MIT")

    version("amd-mainline", branch="amd-mainline", submodules=True, deprecated=True)
    version("amd-staging", branch="amd-staging", submodules=True, deprecated=True)
#    version(
#        "6.4.1",
#        git="https://github.com/ROCm/rocprofiler-systems",
#        tag="rocm-6.4.1",
#        commit="2e945e4a08781e13a822f568814e2c434fd8858f",
#        submodules=True,
#    )
#    version(
#        "6.4.0",
#        git="https://github.com/ROCm/rocprofiler-systems",
#        tag="rocm-6.4.0",
#        commit="c4cec593b6021f2b84294838f2ffe388ed8e911a",
#        submodules=True,
#    )
    version(
        "6.3.3",
        git="https://github.com/ROCm/rocprofiler-systems",
        tag="rocm-6.3.3",
        commit="f03ef1dd9a4e984e3e72056352532e6149e742fc",
        submodules=True,
    )
    version(
        "6.3.2",
        git="https://github.com/ROCm/rocprofiler-systems",
        tag="rocm-6.3.2",
        commit="2fd5fbbef941ff219a1ecef702f8cfaae6e8e5ba",
        submodules=True,
    )
    version(
        "6.3.1",
        git="https://github.com/ROCm/rocprofiler-systems",
        tag="rocm-6.3.1",
        commit="04a84dd0b0df3dfd61f7765696e0e474ec29f10b",
        submodules=True,
    )

    version(
        "6.3.0",
        git="https://github.com/ROCm/rocprofiler-systems",
        tag="rocm-6.3.0",
        commit="71a5e271b5e07efd2948fb6e7b451db5e8e40cb8",
        submodules=True,
    )

    variant(
        "rocm",
        default=True,
        description="Enable ROCm API, kernel tracing, and GPU HW counters support",
    )
    variant("strip", default=False, description="Faster binary instrumentation, worse debugging")
    variant(
        "python", default=False, description="Enable support for Python function profiling and API"
    )
    variant("papi", default=True, description="Enable HW counters support via PAPI")
    variant("ompt", default=True, description="Enable OpenMP Tools support")
    variant(
        "tau",
        default=False,
        description="Enable support for using TAU markers in omnitrace instrumentation",
    )
    variant(
        "caliper",
        default=False,
        description="Enable support for using Caliper markers in omnitrace instrumentation",
    )
    variant(
        "perfetto_tools",
        default=False,
        description="Install perfetto tools (e.g. traced, perfetto)",
    )
    variant(
        "mpi",
        default=False,
        description=(
            "Enable intercepting MPI functions and aggregating output during finalization "
            "(requires target application to use same MPI installation)"
        ),
    )
    variant(
        "mpi_headers",
        default=True,
        description=(
            "Enable intercepting MPI functions but w/o support for aggregating output "
            "(target application can use any MPI installation)"
        ),
    )
    variant("internal-dyninst", default=False, description="build internal dyninst")

    extends("python", when="+python")

    depends_on("c", type="build")  # generated
    depends_on("cxx", type="build")  # generated
    depends_on("fortran", type="build")  # generated

    # hard dependencies
    depends_on("cmake@3.16:", type="build")
    depends_on("dyninst@:12", when="~internal-dyninst")
    depends_on(
        "boost+atomic+chrono+date_time+filesystem+system+thread+timer+container+random+exception",
        when="+internal-dyninst",
    )
    depends_on("libiberty+pic", when="+internal-dyninst")
    depends_on("m4")
    depends_on("texinfo")
    depends_on("libunwind", type=("build", "run"))
    depends_on("papi+shared", when="+papi")
    depends_on("mpi", when="+mpi")
    depends_on("tau", when="+tau")
    depends_on("caliper", when="+caliper")
    depends_on("python@3:", when="+python", type=("build", "run"))
    depends_on("libunwind", when="+rocm")
    depends_on("autoconf", when="+rocm")
    depends_on("automake", when="+rocm")
    depends_on("libtool", when="+rocm")
    with when("+rocm"):
        for ver in ["6.3.0", "6.3.1", "6.3.2", "6.3.3"]:
            depends_on(f"roctracer-dev@{ver}", when=f"@{ver}")
            depends_on(f"rocprofiler-dev@{ver}", when=f"@{ver}")
        for ver in ["6.3.0", "6.3.1", "6.3.2", "6.3.3", "6.4.0", "6.4.1"]:
            depends_on(f"rocm-smi-lib@{ver}", when=f"@{ver}")
            depends_on(f"hip@{ver}", when=f"@{ver}")
#        for ver in ["6.4.0", "6.4.1"]:
#            depends_on(f"rocprofiler-sdk@{ver}", when=f"@{ver}")

    # Fix GCC 13 build failure caused by a missing include of <array> in dyninst
    patch(
        "https://github.com/ROCm/dyninst/commit/09e781d414c83b4ad587083d449a3e976546937d.patch?full_index=1",
        sha256="e64c6b75393e7fbd711c0bd0233628c176a352cd10b4057f00eec283426eaf0a",
        when="@:6.4.0 +internal-dyninst",
        working_dir="external/dyninst",
    )

    patch("fix_filepath.cpp_v6.3.0.patch", when="@6.3.0")
    patch("fix_maps.cpp_v6.3.0.patch", when="@6.3.0")
    patch("fix_ElfUtils.cmake_v6.3.0.patch", when="@6.3.0")

    def cmake_args(self):
        spec = self.spec

        args = [
            self.define("SPACK_BUILD", True),
            self.define("ROCPROFSYS_BUILD_PAPI", False),
            self.define("ROCPROFSYS_BUILD_PYTHON", True),
            self.define("ROCPROFSYS_BUILD_LIBUNWIND", False),
            self.define("ROCPROFSYS_BUILD_STATIC_LIBGCC", False),
            self.define("ROCPROFSYS_BUILD_STATIC_LIBSTDCXX", False),
            self.define_from_variant("ROCPROFSYS_BUILD_DYNINST", "internal-dyninst"),
            self.define_from_variant("DYNINST_BUILD_TBB", "internal-dyninst"),
            self.define_from_variant("ROCPROFSYS_BUILD_LTO", "ipo"),
            self.define_from_variant("ROCPROFSYS_USE_MPI", "mpi"),
            self.define_from_variant("ROCPROFSYS_USE_OMPT", "ompt"),
            self.define_from_variant("ROCPROFSYS_USE_PAPI", "papi"),
            self.define_from_variant("ROCPROFSYS_USE_RCCL", "rocm"),
            self.define_from_variant("ROCPROFSYS_USE_PYTHON", "python"),
            self.define_from_variant("ROCPROFSYS_USE_MPI_HEADERS", "mpi_headers"),
            self.define_from_variant("ROCPROFSYS_STRIP_LIBRARIES", "strip"),
            self.define_from_variant("ROCPROFSYS_INSTALL_PERFETTO_TOOLS", "perfetto_tools"),
            # timemory arguments
            self.define("TIMEMORY_BUILD_CALIPER", False),
            self.define_from_variant("TIMEMORY_USE_TAU", "tau"),
            self.define_from_variant("TIMEMORY_USE_CALIPER", "caliper"),
        ]
        if spec.satisfies("@:6.3"):
            args.append(self.define_from_variant("ROCPROFSYS_USE_ROCM_SMI", "rocm"))
            args.append(self.define_from_variant("ROCPROFSYS_USE_HIP", "rocm"))
            args.append(self.define_from_variant("ROCPROFSYS_USE_ROCTRACER", "rocm"))
            args.append(self.define_from_variant("ROCPROFSYS_USE_ROCPROFILER", "rocm"))
        else:
            args.append(self.define_from_variant("ROCPROFSYS_USE_ROCM", "rocm"))

        if "+tau" in spec:
            tau_root = spec["tau"].prefix
            args.append(self.define("TAU_ROOT_DIR", tau_root))

        if "+mpi" in spec:
            args.append(self.define("MPI_C_COMPILER", spec["mpi"].mpicc))
            args.append(self.define("MPI_CXX_COMPILER", spec["mpi"].mpicxx))

        if spec.satisfies("@6.3:"):
            args.append(self.define("dl_LIBRARY", "dl"))
            args.append(
                self.define("libunwind_INCLUDE_DIR", self.spec["libunwind"].prefix.include)
            )
        return args

    def flag_handler(self, name, flags):
        if self.spec.satisfies("@6.3:"):
            if name == "ldflags":
                flags.append("-lintl")
        return (flags, None, None)

    def setup_build_environment(self, env: EnvironmentModifications) -> None:
        if "+tau" in self.spec:
            import glob

            # below is how TAU_MAKEFILE is set in packages/tau/package.py
            pattern = join_path(self.spec["tau"].prefix.lib, "Makefile.*")
            files = glob.glob(pattern)
            if files:
                env.set("TAU_MAKEFILE", files[0])
