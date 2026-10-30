# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.package import *

try:
    from spack_repo.builtin.packages.meson.package import Meson as BuiltinMeson
except ImportError:
    from spack.pkg.builtin.meson import Meson as BuiltinMeson


class Meson(BuiltinMeson):
    """Retain the Meson version pinned by the Setonix-Q stack."""

    version("1.5.1", sha256="55f6acd5bf72c14d4aa5a781993633f84a1d117bdf2c2057735902ced9b81390")
