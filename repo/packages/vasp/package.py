# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
import grp
import shutil

from spack.package import *


class Vasp(MakefilePackage):
    """
    The Vienna Ab initio Simulation Package (VASP)
    is a computer program for atomic scale materials modelling,
    e.g. electronic structure calculations
    and quantum-mechanical molecular dynamics, from first principles.
    """

    homepage = "https://vasp.at"
    url      = "file://{0}/vasp.5.4.4.pl2.tgz".format(os.getcwd())
    manual_download = True

    version('6.3.0', sha256='adcf83bdfd98061016baae31616b54329563aa2739573f069dd9df19c2071ad3')
    version('6.2.1', sha256='d25e2f477d83cb20fce6a2a56dcee5dccf86d045dd7f76d3ae19af8343156a13')
    version('6.1.1', sha256='e37a4dfad09d3ad0410833bcd55af6b599179a085299026992c2d8e319bf6927')
    version('5.4.4.pl2', sha256='98f75fd75399a23d76d060a6155f4416b340a1704f256a00146f89024035bc8e')
    version('5.4.4', sha256='5bd2449462386f01e575f9adf629c08cb03a13142806ffb6a71309ca4431cfb3')

    resource(name='vaspsol',
             git='https://github.com/henniggroup/VASPsol.git',
             tag='V1.0',
             when='+vaspsol')

    variant('scalapack', default=False,
            description='Enables build with SCALAPACK')

    variant('cuda', default=False,
            description='Enables running on Nvidia GPUs')

    variant('vaspsol', default=False,
            description='Enable VASPsol implicit solvation model\n'
            'https://github.com/henniggroup/VASPsol')

    depends_on('rsync', type='build')
    depends_on('openblas')
    depends_on('lapack')
    depends_on('fftw')
    depends_on('mpi', type=('build', 'link', 'run'))
    depends_on('netlib-scalapack', when='+scalapack')
    depends_on('cuda', when='+cuda')
    depends_on('qd', when='%nvhpc')

    conflicts('%gcc@:8', msg='GFortran before 9.x does not support all features needed to build VASP')
    conflicts('+vaspsol', when='+cuda', msg='+vaspsol only available for CPU')
    conflicts('~scalapack', when='@6.3.0:', msg='scalapack is mandatory for vasp 6.3.0 and later')

    # Patch is adapted from patch provided in master branch of vaspsol:
    # https://github.com/henniggroup/VASPsol/raw/master/src/patches/pbz_patch_610
    # This may have to be further modified for later vasp versions.
    #
    # Note that this patch edits the solvation.F source under the VASPsol directory,
    # which in turn will be copied into the vasp source in the edit stage below.
    patch('vaspsol-6.2.1.patch.1', when='@6.0:+vaspsol')

    parallel = False

    def edit(self, spec, prefix):

        # Following has been adapted from spack development branch, and special casing
        # 6.3.0 for gcc as we're not needing nvhpc support for setonix and aocc is currently
        # broken.

        if spec.satisfies('@6.3.0:'):
            makefile_base = 'makefile.include.'
            if '%gcc' in spec:
                if '+openmp' in spec:
                    make_include = join_path('arch', 'makefile.include.gnu_omp')
                else:
                    make_include = join_path('arch', 'makefile.include.gnu')
            else:
                suffix = ''
                if '+openmp' in spec:
                    suffix = '_omp'

                make_include = join_path('arch', 'makefile.include.{0}{1}'.
                                             format(spec.compiler.name), suffix)
        else:
            if '%gcc' in spec:
                if '+openmp' in spec:
                    make_include = join_path('arch', 'makefile.include.linux_gnu_omp')
                else:
                    make_include = join_path('arch', 'makefile.include.linux_gnu')
            elif '%nvhpc' in spec:
                make_include = join_path('arch', 'makefile.include.linux_pgi')
                filter_file('-pgc++libs', '-c++libs', make_include, string=True)
                filter_file('pgcc', spack_cc, make_include)
                filter_file('pgc++', spack_cxx, make_include, string=True)
                filter_file('pgfortran', spack_fc, make_include)
                filter_file('/opt/pgi/qd-2.3.17/install/include',
                            spec['qd'].prefix.include, make_include)
                filter_file('/opt/pgi/qd-2.3.17/install/lib',
                            spec['qd'].prefix.lib, make_include)
            elif '%aocc' in spec:
                if '+openmp' in spec:
                    copy(
                        join_path('arch', 'makefile.include.linux_gnu_omp'),
                        join_path('arch', 'makefile.include.linux_aocc_omp')
                    )
                    make_include = join_path('arch', 'makefile.include.linux_aocc_omp')
                else:
                    copy(
                        join_path('arch', 'makefile.include.linux_gnu'),
                        join_path('arch', 'makefile.include.linux_aocc')
                    )
                    make_include = join_path('arch', 'makefile.include.linux_aocc')
                filter_file(
                    'gcc', '{0} {1}'.format(spack_cc, '-Mfree'),
                    make_include, string=True
                )
                filter_file('g++', spack_cxx, make_include, string=True)
                filter_file('^CFLAGS_LIB[ ]{0,}=.*$',
                            'CFLAGS_LIB = -O3', make_include)
                filter_file('^FFLAGS_LIB[ ]{0,}=.*$',
                            'FFLAGS_LIB = -O2', make_include)
                filter_file('^OFLAG[ ]{0,}=.*$',
                            'OFLAG = -O3', make_include)
                filter_file('^FC[ ]{0,}=.*$',
                            'FC = {0}'.format(spec['mpi'].mpifc),
                            make_include, string=True)
                filter_file('^FCL[ ]{0,}=.*$',
                            'FCL = {0}'.format(spec['mpi'].mpifc),
                            make_include, string=True)
            else:
                suffix = ''
                if '+openmp' in spec:
                    suffix = '_omp'

                make_include = join_path('arch', 'makefile.include.linux_{0}{1}'.
                                             format(spec.compiler.name), suffix)

        shutil.copy(make_include, 'makefile.include')

        # This bunch of 'filter_file()' is to make these options settable
        # as environment variables
        filter_file('^CPP_OPTIONS[ ]{0,}=[ ]{0,}',
                    'CPP_OPTIONS ?= ',
                    'makefile.include')
        filter_file('^FFLAGS[ ]{0,}=[ ]{0,}',
                    'FFLAGS ?= ',
                    'makefile.include')

        filter_file('^LIBDIR *=.*$', '', 'makefile.include')
        filter_file('^BLAS *=.*$', 'BLAS ?=', 'makefile.include')
        filter_file('^LAPACK *=.*$', 'LAPACK ?=', 'makefile.include')
        filter_file('^FFTW *\?=.*$', 'FFTW ?=', 'makefile.include')
        filter_file('^MPI_INC *=.*$', 'MPI_INC ?=', 'makefile.include')
        filter_file('-DscaLAPACK.*$\n', '', 'makefile.include')
        filter_file('^SCALAPACK.*$', '', 'makefile.include')
        filter_file('^OBJECTS_LIB *= *', 'OBJECTS_LIB = getshmem.o ', 'makefile.include')

        if '+cuda' in spec:
            filter_file('^OBJECTS_GPU[ ]{0,}=.*$',
                        'OBJECTS_GPU ?=',
                        'makefile.include')

            filter_file('^CPP_GPU[ ]{0,}=.*$',
                        'CPP_GPU ?=',
                        'makefile.include')

            filter_file('^CFLAGS[ ]{0,}=.*$',
                        'CFLAGS ?=',
                        'makefile.include')

        if '+vaspsol' in spec:
            copy('VASPsol/src/solvation.F', 'src/')

    def setup_build_environment(self, spack_env):
        spec = self.spec

        cpp_options = ['-DMPI -DMPI_BLOCK=8000',
                       '-Duse_collective', '-DCACHE_SIZE=4000',
                       '-Davoidalloc', '-Duse_bse_te',
                       '-Dtbdyn', '-Duse_shmem']
        if '%nvhpc' in self.spec:
            cpp_options.extend(['-DHOST=\\"LinuxPGI\\"', '-DPGI16',
                                '-Dqd_emulate'])
        else:
            cpp_options.append('-DHOST=\\"LinuxGNU\\"')
        if self.spec.satisfies('@6:'):
            cpp_options.append('-Dvasp6')

        cflags = ['-fPIC', '-DADD_']
        fflags = []
        if '%gcc' in spec or '%intel' in spec:
            fflags.append('-w')
        elif '%nvhpc' in spec:
            fflags.extend(['-Mnoupcase', '-Mbackslash', '-Mlarge_arrays'])

        spack_env.set('BLAS', spec['blas'].libs.ld_flags)
        spack_env.set('LAPACK', spec['lapack'].libs.ld_flags)
        spack_env.set('FFTW', spec['fftw'].prefix)
        spack_env.set('FFTW_ROOT', spec['fftw'].prefix)
        spack_env.set('MPI_INC', spec['mpi'].prefix.include)

        if '%nvhpc' in spec:
            spack_env.set('QD', spec['qd'].prefix)

        if '+scalapack' in spec or spec.satisfies('@6.3.0:'):
            cpp_options.append('-DscaLAPACK')
            spack_env.set('SCALAPACK', spec['netlib-scalapack'].libs.ld_flags)

        if '+cuda' in spec:
            cpp_gpu = ['-DCUDA_GPU', '-DRPROMU_CPROJ_OVERLAP',
                       '-DCUFFT_MIN=28', '-DUSE_PINNED_MEMORY']

            objects_gpu = ['fftmpiw.o', 'fftmpi_map.o', 'fft3dlib.o',
                           'fftw3d_gpu.o', 'fftmpiw_gpu.o']

            cflags.extend(['-DGPUSHMEM=300', '-DHAVE_CUBLAS'])

            spack_env.set('CUDA_ROOT', spec['cuda'].prefix)
            spack_env.set('CPP_GPU', ' '.join(cpp_gpu))
            spack_env.set('OBJECTS_GPU', ' '.join(objects_gpu))

        if '+vaspsol' in spec:
            cpp_options.append('-Dsol_compat')

        if spec.satisfies('%gcc@10:'):
            fflags.append('-fallow-argument-mismatch')

        # Finally
        spack_env.set('CPP_OPTIONS', ' '.join(cpp_options))
        spack_env.set('CFLAGS', ' '.join(cflags))
        spack_env.set('FFLAGS', ' '.join(fflags))

    def build(self, spec, prefix):
        if '+cuda' in self.spec:
            make('gpu', 'gpu_ncl')
        else:
            make('std', 'gam', 'ncl')

    def install(self, spec, prefix):
        install_tree('bin/', prefix.bin)

        newgrp = "vasp"
        if spec.satisfies('@6:'):
            newgrp = "vasp6"

        gid = grp.getgrnam(newgrp).gr_gid
        for dpath, dnames, fnames in os.walk(prefix.bin):
            for fn in fnames:
                os.chown(os.path.join(dpath, fn), -1, gid)
