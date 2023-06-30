# Copyright 2013-2022 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# can remove
import sys

from spack.package import *


class TowerCli(Package):
    """Tower on the Command Line brings Nextflow Tower concepts
       including Pipelines, Actions and Compute Environments
       to the terminal.
    """

    homepage = "https://github.com/seqeralabs/tower-cli"

    if sys.platform == 'darwin':
        url      = "https://github.com/seqeralabs/tower-cli/releases/download/v0.7.0/tw-0.7.0-osx-x86_64"
        version('0.7.0', sha256='b1b3ade4231de2c7303832bac406510c9de171d07d6384a54945903f5123f772', expand=False)
    elif sys.platform.startswith('linux'):
        url      = "https://github.com/seqeralabs/tower-cli/releases/download/v0.7.0/tw-0.7.0-linux-x86_64"
        version('0.7.0', sha256='651f564b80585c9060639f1a8fc82966f81becb0ab3e3ba34e53baf3baabff39', expand=False)

    def install(self, spec, prefix):
        mkdirp(prefix.bin)
        install(self.stage.archive_file, join_path(prefix.bin, "tw"))
        set_executable(join_path(prefix.bin, "tw"))
