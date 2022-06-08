# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

# ----------------------------------------------------------------------------
# If you submit this package back to Spack as a pull request,
# please first remove this boilerplate and all FIXME comments.
#
# This is a template package file for Spack.  We've put "FIXME"
# next to all the things you'll want to change. Once you've handled
# them, you can save this file and test your package like this:
#
#     spack install ansys-fluidstructures
#
# You can edit this file again by typing:
#
#     spack edit ansys-fluidstructures
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------
import os
import shutil
import stat

import platform
import re

from spack.util.prefix import Prefix
from spack import *

class AnsysFluidstructures(Package):
    """
    Ansys computational fluid dynamics (CFD) products are for engineers who need to make better, faster decisions. 
    Our CFD simulation products have been validated and are highly regarded for their superior computing power and 
    accurate results. Reduce development time and efforts while improving your product’s performance and safety.
    """

    homepage = "https://www.ansys.com/products/fluids"
    url = "file://{0}/FLUIDSTRUCTURES2022R1.tgz".format(os.getcwd())
    manual_download = True


    maintainers = ['Basha', 'Pascal Elahi']


    version('2022R1',sha256='3dbb33d8e6de511cf42e334d983c138cec9c8b016baf1e42413836bc0c5e2663')
    versiontoansysversion = ('2022R1', 'v221')

    preferred_version = "2022R1"

    # define installtion
    def install(self, spec, prefix):
        # maali code has
        # make ./INSTALL in src directory executable and then run
        # run the executable that does it all
        # mkdirp('{0}/{1}'.format(self.stage.source_path, 'fluidstructures_tmpdir'))
        # run_install = Executable("./INSTALL -silent -install_dir {0} -usetempdir {1}/{2}".format(self.prefix, self.stage.source_path, 'fluidstructures_tmpdir'))
        # due to installer requiring an installation path with < 100 characters, to temporary install
        tmp_install_path = '/scratch/pawsey0001/spack/tmp/'
        mkdirp('{0}/{1}'.format(self.stage.source_path, 'fluidstructures_tmpdir'))
        mkdirp('{0}/{1}'.format(tmp_install_path, 'fluidstructures'))
        run_install = Executable("./INSTALL -silent -install_dir {0}/{1} -usetempdir {2}/{3}".format(tmp_install_path, 'fluidstructures', self.stage.source_path, 'fluidstructures_tmpdir'))
        run_install()

        # change internal wrapper for launching fluent from mpirun to srun and also alter the platform using sed
        sed=which('sed')
        sed('/# start job/ i my_cmdline=\"srun --export=ALL -n \$FS_NPROC \$FS_CMD\"',"{0}/{1}/v221/fluent/fluent22.1.0/multiport/mpi_wrapper/bin/mpirun.fl".format(tmp_install_path, 'fluidstructures'))
        sed("s/platform = None/platform = \'linx64\'/g","{0}/{1}/v221/commonfiles/CPython/3_7/linx64/Release/Ansys/Util/Platform.py".format(tmp_install_path, 'fluidstructures'))
        sed('s/distcmd="mpirun"/distcmd="srun --export=ALL"/g',"{0}/{1}/v221/ansys/bin/anssh.ini".format(tmp_install_path, 'fluidstructures'))
        sed('/distcmd/ s/ -np / -n /g',"{0}/{1}/v221/ansys/bin/ansys221".format(tmp_install_path, 'fluidstructures'))
        sed('/distcmd/ s/ \${extra_mpi_args} / /g',"{0}/{1}/v221/ansys/bin/ansys221".format(tmp_install_path, 'fluidstructures'))
        sed('/KMP_AFFINITY/ s/norespect/disabled/g',"{0}/{1}/v221/ansys/bin/anssh.ini".format(tmp_install_path, 'fluidstructures'))

        # for some strange reason, ansys creates a read only file in the temp directory.
        # fix this by changing the permissions so that the temp directory can be deleted.
        os.system('chmod -R +w {0}/{1}'.format(self.stage.source_path, 'fluidstructures_tmpdir'))
        os.system('chmod -R +w {0}/{1}'.format(tmp_install_path, 'fluidstructures'))
        shutil.move("{0}/{1}".format(tmp_install_path, 'fluidstructures'), self.prefix)

        # do not set group permission for ansys here, do it in a follow up script

    def setup_run_environment(self, env):
        #env.set('ANSYS_VERSION', versiontoansysversion[self.version])
        env.prepend_path('PATH', "{0}/fluidstructures/v221/Framework/bin/Linux64/".format(self.prefix))
        env.prepend_path('PATH', "{0}/fluidstructures/v221/fluent/bin/".format(self.prefix))
        env.prepend_path('PATH', "{0}/fluidstructures/v221/ansys/bin/".format(self.prefix))
        ldpathlist=[
	    "/ansys/lib/linx64/",
	    "/ansys/syslib/ansGRPC/",
	    "/ansys/syslib/boost/",
            "/ansys/lib/linx64/intel/",
            "/commonfiles/AAS/bin/linx64/",
            "/commonfiles/AMD/BLIS/v3.0.0/linx64/lib/",
            "/ansys/lib/linx64/amd/",
            "/ansys/lib/linx64/blas/intel/",
            "/ansys/lib/linx64/blas/amd/",
            "/commonfiles/Tcl/lib/linx64/",
            "/Electronics/Linux64/defer/",
            "/fluent/lib/lnamd64/",
            "/tp/hdf5/1_10_5/linx64/lib/",
            "/fluent/fluent22.1.0/cortex/lnamd64/",
            "/fluent/fluent22.1.0/multiport/lnamd64/mpi/shared/",
            "/fluent/fluent22.1.0/multiport/mpi_wrapper/lnamd64/intel/",
            "/tp/IntelMKL/2021.3.0/linx64/lib/intel64/",
            "/dcs/",
            "/tp/qt/5.9.6/linx64/lib/",
            "/tp/IntelCompiler/2019.3.199/linx64/lib/intel64/",
            "/fluent/fluent22.1.0/utility/viewfac/multiport/mpi/lnamd64/intel/lib/",
        ]
        for l in ldpathlist:
            env.prepend_path('LD_LIBRARY_PATH', "{0}/fluidstructures/v221/{1}".format(self.prefix,l))

	
