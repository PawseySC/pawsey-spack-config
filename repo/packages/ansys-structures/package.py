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
#     spack install ansys-structures
#
# You can edit this file again by typing:
#
#     spack edit ansys-structures
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

import os
import shutil
import stat

import platform
import re

from spack.util.prefix import Prefix
from spack.package import *

class AnsysStructures(Package):
    """
    Ansys Mechanical enables you to solve complex structural engineering problems and make better, faster design decisions. 
    With the finite element analysis (FEA) solvers available in the suite, you can customize and automate solutions for 
    your structural mechanics problems and parameterize them to analyze multiple design scenarios. Ansys Mechanical is a 
    dynamic tool that has a complete range of analysis tools.
    """

    homepage = "https://www.ansys.com/products/fluids"
    url = "file://{0}/STRUCTURES2022R1.tgz".format(os.getcwd())
    manual_download = True
    

    maintainers = ['Basha', 'Pascal Elahi']
    

    version('2022R1',sha256='e7f6c09eee0be532ac993564214fea7531fb77e90be64ae308102bb7bece4e74')
    versiontoansysversion = ('2022R1', 'v221')

    preferred_version = "2022R1"

    # define installtion 
    def install(self, spec, prefix):
        # maali code has 
        # make ./INSTALL in src directory executable and then run 
	# run the executable that does it all 
        # mkdirp('{0}/{1}'.format(self.stage.source_path, 'structures_tmpdir'))
        # run_install = Executable("./INSTALL -silent -install_dir {0} -usetempdir {1}/{2}".format(self.prefix, self.stage.source_path, 'structures_tmpdir'))
        # due to installer requiring an installation path with < 100 characters, to temporary install 
        tmp_install_path = os.environ['MYSCRATCH']+'/tmp/'
        mkdirp('{0}/{1}'.format(self.stage.source_path, 'structures_tmpdir'))
        mkdirp('{0}/{1}'.format(tmp_install_path, 'structures'))
        run_install = Executable("./INSTALL -silent -install_dir {0}/{1} -usetempdir {2}/{3}".format(tmp_install_path,'structures', self.stage.source_path,'structures_tmpdir'))
        run_install()
        # replace the mpirun command with the appropriate srun command. 
        # and update some runtime parameters
        sed=which('sed')
        sed('s/distcmd="mpirun"/distcmd="srun --export=ALL"/g',"{0}/{1}/v221/ansys/bin/anssh.ini".format(tmp_install_path, 'structures'))
        sed('/distcmd/ s/ -np / -n /g',"{0}/{1}/v221/ansys/bin/ansys221".format(tmp_install_path, 'structures'))
        sed('/distcmd/ s/ \${extra_mpi_args} / /g',"{0}/{1}/v221/ansys/bin/ansys221".format(tmp_install_path, 'structures'))
        sed('/KMP_AFFINITY/ s/norespect/disabled/g',"{0}/{1}/v221/ansys/bin/anssh.ini".format(tmp_install_path, 'structures'))
        sed("s/platform = None/platform = \'linx64\'/g", "{0}/{1}/v221/commonfiles/CPython/3_7/linx64/Release/Ansys/Util/Platform.py".format(tmp_install_path, 'structures'))

        # for some strange reason, ansys creates a read only file in the temp directory.
        # fix this by changing the permissions so that the temp directory can be deleted. 
        os.system('chmod -R +w {0}/{1}'.format(self.stage.source_path, 'structures_tmpdir'))
        os.system('chmod -R +w {0}/{1}'.format(tmp_install_path, 'structures'))
        shutil.move("{0}/{1}".format(tmp_install_path, 'structures'), self.prefix)  

        # do not set group permission for ansys here, do it in a follow up script

    def setup_run_environment(self, env):
        #env.set('ANSYS_VERSION', versiontoansysversion[self.version])
        env.prepend_path('PATH', "{0}/structures/v221/Framework/bin/Linux64/".format(self.prefix))
        env.prepend_path('PATH', "{0}/structures/v221/ansys/bin/".format(self.prefix))
        ldpathlist=[
	    "/ansys/lib/linx64/", 
            "/commonfiles/AAS/bin/linx64/", 
            "/ansys/syslib/ansGRPC/",
            "/commonfiles/Tcl/lib/linx64/", 
            "/tp/zlib/1_2_11/linx64/lib/",
            "/Electronics/Linux64/defer/",
            "/tp/hdf5/1_10_5/linx64/lib/",
	    "/tp/qt/5.9.6/linx64/lib/", 
            "/dcs/",            
            "/ansys/syslib/boost/",
            "/ansys/lib/linx64/blas/intel/",
            "/ansys/lib/linx64/blas/amd/",
            "/commonfiles/AMD/BLIS/v3.0.0/linx64/lib/",
            "/tp/IntelCompiler/2019.3.199/linx64/lib/intel64/",
            "/tp/IntelMKL/2020.0.166/linx64/lib/intel64/",           

        ]
        for l in ldpathlist:
            env.prepend_path('LD_LIBRARY_PATH', "{0}/structures/v221/{1}".format(self.prefix,l))


