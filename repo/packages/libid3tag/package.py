# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack_repo.builtin.packages.libid3tag.package import Libid3tag as BuiltinLibid3tag

from spack.package import *


class Libid3tag(BuiltinLibid3tag):
    """Declare the C++ compiler probed by the bundled Libtool configure checks."""

    depends_on("cxx", type="build")
