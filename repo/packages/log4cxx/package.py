# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack_repo.builtin.build_systems.cmake import CMakePackage

from spack.package import *


class Log4cxx(CMakePackage):
    """A C++ port of Log4j"""

    homepage = "https://logging.apache.org/log4cxx/latest_stable/"
    url = "https://dlcdn.apache.org/logging/log4cxx/1.8.0/apache-log4cxx-1.8.0.tar.gz"
    maintainers("nicmcd")

    license("Apache-2.0", checked_by="wdconinc")

    version("1.8.0", sha256="6a2e40dfa6b81a9a814ef2083d181b254f88324efff678368e5e61188a58fd3d")

    variant(
        "cxxstd", default="20", description="C++ standard", values=("11", "17", "20"), multi=False
    )

    depends_on("cmake@3.13:", type="build")

    depends_on("apr-util")
    depends_on("apr")
    depends_on("boost+thread+system", when="cxxstd=11")
    depends_on("expat")
    depends_on("zlib-api")
    depends_on("zip")
    depends_on("c", type="build")
    depends_on("cxx", type="build")

    def cmake_args(self):
        return [
            self.define_from_variant("CMAKE_CXX_STANDARD", "cxxstd"),
            self.define("BUILD_TESTING", "off"),
        ]
