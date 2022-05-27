# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
import platform
import re

from spack.util.prefix import Prefix

class Ansysfluids(Package):
    """
    Ansys computational fluid dynamics (CFD) products are for engineers who need to make better, faster decisions. Our CFD simulation products have been validated and are highly regarded for their superior computing power and accurate results. Reduce development time and efforts while improving your product’s performance and safety.
    """

    homepage = "https://www.ansys.com/products/fluids"
    url = "file://{0}/FLUIDS_{1}_LINUX64.tgz".format(os.getcwd(), version)
    manual_download = True

    maintainers = ['Basha', 'Pascal Elahi']

    version('2022R1', sha256='??')
    versiontoansysversion = ('2022R1': 'v221')

    preferred_version = "2022R1"

    # define installtion 
    def install(self, spec, prefix):
        # maali code has 
        # make ./INSTALL in src directory executable and then run 
        # idea is should have something like the following
        # based on amber
        install_tree('ansysfluids_tmpdir', '.')
        shutil.rmtree(join_path(self.stage.source_path, 'ansysfuilds_tmpdir'))
        # run the executable that does it all 
        run_install = Executable("./INSTALL -silent -install_dir {0} -usetempdir {1}".format(self.prefix???, self.stage.source_path))
        # need to look into how spack wants to define the install_directory and build_directory

        # do not set group permission for ansys here, do it in a follow up script

    def setup_run_environment(self, env):
        #env.set('ANSYS_VERSION', versiontoansysversion[self.version])
        env.prepend_path('PATH', "{0}/{1}/Framework/bin/Linux64/".format(self.prefix, versiontoansysversion[self.version]))
        env.prepend_path('PATH', "{0}/{1}/ansys/bin/".format(self.prefix, versiontoansysversion[self.version]))
        ldpathlist=[
            "/ansys/lib/linx64/", 
            "/commonfiles/AAS/bin/linx64/", 
            "/ansys/syslib/ansGRPC/",
            "/commonfiles/Tcl/lib/linx64/", 
            "/tp/zlib/1_2_11/linx64/lib/",
            "/Electronics/Linux64/defer/"
            "/tp/hdf5/1_10_5/linx64/lib 
            "/dcs/",
            "/Framework/bin/Linux64/",
            "/ansys/syslib/boost/",
            "/ansys/lib/linx64/intel/",
            "/ansys/lib/linx64/amd/",
            "/commonfiles/AMD/BLIS/v3.0.0/linx64/lib/",
        ]
        for l in ldpathlist:
            env.prepend_path('LD_LIBRARY_PATH', "{0}/{1}/{2}".format(self.prefix, versiontoansysversion[self.version],l))

