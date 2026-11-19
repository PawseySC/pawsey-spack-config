# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack_repo.builtin.packages.rclone.package import Rclone as BuiltinRclone

from spack.package import *


class Rclone(BuiltinRclone):
    """Rclone with the Setonix-Q release and Pawsey Lustre workaround."""

    version("1.72.1", sha256="227b84024e7e72056f716ee520c4db8b88ec5f80dc83f0899b431b2ce2b25f9b")
    depends_on("go@1.25.5:", type="build", when="@1.72:")

    def setup_run_environment(self, env):
        env.set("RCLONE_LOCAL_NO_PREALLOCATE", "TRUE")
