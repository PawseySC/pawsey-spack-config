# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *


class Miniocli(MakefilePackage):
    """MinIO Client (mc) provides a modern alternative to UNIX commands
    like ls, cat, cp, mirror, diff etc. It supports filesystems and
    Amazon S3 compatible cloud storage service (AWS Signature v2 and v4)."""

    homepage = "https://docs.min.io/docs/minio-client-complete-guide.html"
    url      = "https://github.com/minio/mc/archive/refs/tags/RELEASE.2022-02-02T02-03-24Z.tar.gz"

    version('2022-01-05T23-52-51Z', sha256='d5dbd32b7a7f79baace09dd6518121798d2fcbb84b81046b61ff90f980c8f963')
    version('2022-02-02T02-03-24Z', sha256='2d4a64c17935d40d0e325761cc214b2efceb19ce006101c192da9b31f8920a97')

    depends_on('go', type='build')

    def url_for_version(self, version):
        return ("https://github.com/minio/mc/archive/RELEASE.{0}.tar.gz".format(version))

    def install(self, spec, prefix):
        go('build')
        mkdirp(prefix.bin)
        install('mc', prefix.bin)
