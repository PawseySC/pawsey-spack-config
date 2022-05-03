# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *


class Wsclean(CMakePackage):
    """
    WSClean (w-stacking clean) is a fast generic widefield imager. It uses the w-stacking algorithm 
    and can make use of the w-snapshot algorithm. As of Feb 2014, it is 2-12 times faster than CASA's 
    w-projection, depending on the array configuration. It supports full-sky imaging and proper beam 
    correction for homogeneous dipole arrays such as the MWA.
    WSClean allows Hogbom and Cotton-Schwab cleaning and has wideband, multiscale, compressed 
    sensing and joined-polarization deconvolution modes. All operations are performed on the CPU.
    """

    homepage = "https://wsclean.readthedocs.io/en/latest/"
    url      = "https://sourceforge.net/projects/wsclean/files/wsclean-2.10/wsclean-2.10.1.tar.bz2/download"

    version('2.10.1', sha256='d5dbd32b7a7f79baace09dd6518121798d2fcbb84b81046b61ff90f980c8f963')

    depends_on('chgcentre', type='build')
    depends_on('casacore')
    depends_on('fftw-api@3')
    depends_on('idg')
    depends_on('gsl')
    depends_on('cfitsio')


    # maali cygnet has odd patching
    #sed -i 's/fftw_make_planner_thread_safe()/void fftw_make_planner_thread_safe(void)/g' wsclean/*.cpp
    #sed -i 's/fftwf_make_planner_thread_safe()/void fftwf_make_planner_thread_safe(void)/g' wsclean/*.cpp

    def url_for_version(self, version):
        return ("https://sourceforge.net/projects/wsclean/files/wsclean-{0}/wsclean-{0}.tar.bz2/download".format(version))

#     def cmake_args(self):
#         args = []
#         spec = self.spec



#     export CC=gcc
#     export CXX="g++ -std=c++11" 
# export CXXFLAGS="-fPIC -std=c++11"
#     mkdir -p build
#     cd build

# maali_run "cmake ..  -DCMAKE_INSTALL_PREFIX=${MAALI_INSTALL_DIR} -DCFITSIO_ROOT_DIR=${MAALI_CFITSIO_HOME} -DIDGAPI_LIBRARIES=${MAALI_IDG_HOME}/lib/libidg-api.so -DIDGAPI_INCLUDE_DIRS=${MAALI_IDG_HOME}/include -DFFTW3_LIB=${MKLROOT}/lib/intel64 -DCASACORE_ROOT_DIR=${MAALI_CASACORE_HOME} -DFFTW3F_THREADS_LIB=${MKLROOT}/lib/intel64 -DGSL_INCLUDE_DIR=$MAALI_GSL_HOME/include -DGSL_LIB=$MAALI_GSL_HOME/lib/libgsl.a -DGSL_CBLAS_LIB=$MAALI_GSL_HOME/lib/libgslcblas.a -DFFTW3F_LIB=${MKLROOT}/lib/intel64 -DFFTW3_THREADS_LIB=${MKLROOT}/lib/intel64 -DFFTW3_INCLUDE_DIR=${MKLROOT}/include/fftw"

#     maali_run "make -j12 VERBOSE=1"
#     maali_run "make install"

# }

#         args.append(self.define_from_variant('ENABLE_SHARED', 'shared'))
#         args.append(self.define_from_variant('USE_OPENMP', 'openmp'))
#         args.append(self.define_from_variant('USE_READLINE', 'readline'))
#         args.append(self.define_from_variant('USE_HDF5', 'hdf5'))
#         args.append(self.define_from_variant('USE_ADIOS2', 'adios2'))
#         args.append(self.define_from_variant('USE_MPI', 'adios2'))
#         if spec.satisfies('+adios2'):
#             args.append(self.define('ENABLE_TABLELOCKING', False))

#         # fftw3 is required by casacore starting with v3.4.0, but the
#         # old fftpack is still available. For v3.4.0 and later, we
#         # always require FFTW3 dependency with the optional addition
#         # of FFTPack. In older casacore versions, only one of FFTW3 or
#         # FFTPack can be selected.
#         if spec.satisfies('@3.4.0:'):
#             if spec.satisfies('+fftpack'):
#                 args.append('-DBUILD_FFTPACK_DEPRECATED=YES')
#             args.append(self.define('USE_FFTW3', True))
#         else:
#             args.append(self.define('USE_FFTW3', spec.satisfies('~fftpack')))

#         # Python2 and Python3 binding
#         if spec.satisfies('~python'):
#             args.extend(['-DBUILD_PYTHON=NO', '-DBUILD_PYTHON3=NO'])
#         elif spec.satisfies('^python@3.0.0:'):
#             args.extend(['-DBUILD_PYTHON=NO', '-DBUILD_PYTHON3=YES'])
#         else:
#             args.extend(['-DBUILD_PYTHON=YES', '-DBUILD_PYTHON3=NO'])

#         args.append('-DBUILD_TESTING=OFF')
#         return args
