# Copyright 2026 Pawsey Supercomputing Centre
#
# SPDX-License-Identifier: BSD-3-Clause

from spack.package import *

try:
    from spack_repo.builtin.packages.protobuf.package import Protobuf as BuiltinProtobuf
except ImportError:
    from spack.pkg.builtin.protobuf import Protobuf as BuiltinProtobuf


class Protobuf(BuiltinProtobuf):
    """Use the portable ARM CRC32 intrinsic with Protobuf 32.1."""

    # https://github.com/protocolbuffers/protobuf/commit/cbe193ab7ef6f8979cc33a876073217b364f4118
    patch("arm-crc32-acle.patch", when="@32.1")
