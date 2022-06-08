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
#     spack install ansys-fluids
#
# You can edit this file again by typing:
#
#     spack edit ansys-fluids
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

class AnsysFluids(Package):
    """
    Ansys computational fluid dynamics (CFD) products are for engineers who need to make better, faster decisions. Our CFD simulation products have been validated and are highly regarded for their superior computing power and accurate results. Reduce development time and efforts while improving your product’s performance and safety.
    """

    homepage = "https://www.ansys.com/products/fluids"
    url = "file://{0}/FLUIDS2022R1.tgz".format(os.getcwd())
    manual_download = True
    

    maintainers = ['Basha', 'Pascal Elahi']
    

    version('2022R1',sha256='cb61c6e48ad1272a9cf9d70afc228c0e5c0deef0ba8264a9b40fbef6ceedf351')
    versiontoansysversion = ('2022R1', 'v221')

    preferred_version = "2022R1"

    # define installtion 
    def install(self, spec, prefix):
        # maali code has 
        # make ./INSTALL in src directory executable and then run 
	# run the executable that does it all 
        # mkdirp('{0}/{1}'.format(self.stage.source_path, 'ansysfluids_tmpdir'))
        # run_install = Executable("./INSTALL -silent -install_dir {0} -usetempdir {1}/{2}".format(self.prefix, self.stage.source_path, 'fluids_tmpdir'))
        # due to installer requiring an installation path with < 100 characters, to temporary install 
        tmp_install_path = '/scratch/pawsey0001/spack/tmp/'
        mkdirp('{0}/{1}'.format(self.stage.source_path, 'fluids_tmpdir'))
        mkdirp('{0}/{1}'.format(tmp_install_path, 'fluids'))
        run_install = Executable("./INSTALL -silent -install_dir {0}/{1} -usetempdir {2}/{3}".format(tmp_install_path, 'fluids', self.stage.source_path, 'fluids_tmpdir'))
        run_install()
        # change internal wrapper for launching fluent from mpirun to srun and also alter the platform using sed
        sed=which('sed')
        # find comments before start job and insert the new my_cdmline 
        sed('/# start job/ i my_cmdline=\"srun --export=ALL -n \$FS_NPROC \$FS_CMD\"', "{0}/{1}/v221/fluent/fluent22.1.0/multiport/mpi_wrapper/bin/mpirun.fl".format(tmp_install_path, 'fluids'))
        # change the default platform
        sed("s/platform = None/platform = \'linx64\'/g", "{0}/{1}/v221/commonfiles/CPython/3_7/linx64/Release/Ansys/Util/Platform.py".format(tmp_install_path, 'fluids'))
        
        #for some strange reason, ansys creates a read only file in the temp directory.
        # fix this by changing the permissions so that the temp directory can be deleted. 
        os.system('chmod -R +w {0}/{1}'.format(self.stage.source_path, 'fluids_tmpdir'))
        os.system('chmod -R +w {0}/{1}'.format(tmp_install_path, 'fluids'))
        shutil.move("{0}/{1}".format(tmp_install_path, 'fluids'), self.prefix)  

        # do not set group permission for ansys here, do it in a follow up script

    def setup_run_environment(self, env):
        #env.set('ANSYS_VERSION', versiontoansysversion[self.version])
        env.prepend_path('PATH', "{0}/fluids/v221/Framework/bin/Linux64/".format(self.prefix))
        env.prepend_path('PATH', "{0}/fluids/v221/fluent/bin/".format(self.prefix))
        ldpathlist=[
            "/fluent/lib/lnamd64/",
            "/tp/hdf5/1_10_5/linx64/lib/",
            "/fluent/fluent22.1.0/cortex/lnamd64/",
            "/fluent/fluent22.1.0/multiport/lnamd64/mpi/shared/",
            "/fluent/fluent22.1.0/multiport/mpi_wrapper/lnamd64/intel/",
            "/tp/IntelMKL/2021.3.0/linx64/lib/intel64/",
            "/dcs/",
            "/tp/IntelCompiler/2019.3.199/linx64/lib/intel64/",
	    "/tp/qt/5.9.6/lin64/lib/",
            "/fluent/fluent22.1.0/utility/viewfac/multiport/mpi/lnamd64/intel/lib/",
        ]
        for l in ldpathlist:
            env.prepend_path('LD_LIBRARY_PATH', "{0}/fluids/v221/{1}".format(self.prefix,l))



