# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
# Nektar builds its own boost and other packages - better than let spack handling it.
from spack.package import *
from spack.util.environment import is_system_path
from llnl.util import tty
from llnl.util.filesystem import FileFilter

import os

class Nektar(CMakePackage):
    """Nektar++: Spectral/hp Element Framework"""

    homepage = "https://www.nektar.info/"
#    url      = "https://gitlab.nektar.info/nektar/nektar/-/archive/v4.4.1/nektar-v4.4.1.tar.bz2"
    url      = "file://{0}/nektar-v5.0.2.tar.bz2".format(os.getcwd())
    manual_download = True
    #version('5.2.0', sha256="")
    version('5.1.0', sha256='f5fdb729909e4dcd42cb071f06569634fa87fe90384ba0f2f857a9e0e56b6ac5')
    version('5.0.3', sha256='1ef6f8f94f850ae78675bca3f752aa6c9f75401d1d6da4ec25df7fa795b860e9')
    version('5.0.2', sha256='24af60a48dbdf0455149540b35a6a59acd636c47b3150b261899a1a1ca886c0b')
    version('5.0.0', sha256='5c594453fbfaa433f732a55405da9bba27d4a00c32d7b9d7515767925fb4a818')
    version('4.4.1', sha256='71cfd93d848a751ae9ae5e5ba336cee4b4827d4abcd56f6b8dc5c460ed6b738c')

    variant('mpi', default=True, description='Builds with mpi support')
    variant('avx2', default=True, description='Builds with simd avx2 support')
    variant('fftw', default=True, description='Builds with fftw support')
    variant('arpack', default=True, description='Builds with arpack support')
    variant('hdf5', default=True, description='Builds with hdf5 support')
    variant('scotch', default=False,
            description='Builds with scotch partitioning support')
    variant('unit-tests', default=False, description='Builds unit tests')
    variant('regression-tests', default=False, description='Builds regression tests')
    variant('benchmarking-tests', default=False, description='Builds benchmark timing codes')
    variant('python', default=False, description='Builds python bindings')

    # depends_on('cmake@2.8.8:', type='build', when="~hdf5")
    # depends_on('cmake@3.2:', type='build', when="+hdf5")

    depends_on('tinyxml', when='platform=darwin')
    depends_on('mpi', when='+mpi')
    depends_on('blas')
    depends_on('lapack')
    # depends_on('boost@1.57.0 ~atomic ~chrono ~exception +filesystem ~graph +iostreams ~locale ~log ~math ~mpi +multithreaded ~numpy +pic ~program_options ~python ~random +regex ~serialization ~signals +system ~test +thread ~timer ~wave')

    depends_on(
        "boost@1.72.0: +thread +iostreams +filesystem +system +program_options +regex +pic"
        "+python +numpy",
        when="+python",
    )
    depends_on(
        "boost@1.72.0: +thread +iostreams +filesystem +system +program_options +regex +pic",
        when="~python",
    )

    depends_on('fftw@3.0: +mpi', when="+mpi+fftw")
    depends_on('fftw@3.0: ~mpi', when="~mpi+fftw")
    depends_on('arpack-ng +mpi', when="+arpack+mpi")
    depends_on('arpack-ng ~mpi', when="+arpack~mpi")
    depends_on('hdf5 +mpi +hl', when="+mpi+hdf5")
    depends_on('scotch ~mpi ~metis', when="~mpi+scotch")
    depends_on('scotch +mpi ~metis', when="+mpi+scotch")

    conflicts('+hdf5', when='~mpi',
              msg='Nektar hdf5 output is for parallel builds only')

#    phases = ['edit', 'cmake', 'build', 'install']


#    def edit(self, spec, prefix):
#        # Existing edit logic...
#    
#        # Inject compiler flag into Boost bootstrap
#        boost_build_dir = join_path(self.stage.source_path, "ThirdParty", "boost")
#        bootstrap_file = join_path(boost_build_dir, "bootstrap.sh")
#    
#        if os.path.exists(bootstrap_file):
#            # Backup original file
#            import shutil
#            shutil.copy(bootstrap_file, bootstrap_file + ".orig")
#    
#            # Inject CFLAGS into bootstrap
#            ff = FileFilter(bootstrap_file)
#            ff.filter(
#                r'^CFLAGS=""',
#                'CFLAGS="-Wno-error=implicit-function-declaration"'
#            )

#    def edit(self, spec, prefix):
#        ...
#        # Patch Boost source before building jam0
#        boost_path_c = join_path(self.stage.source_path, "ThirdParty", "boost", "tools", "build", "src", "modules", "path.c")
#        if os.path.exists(boost_path_c):
#            with open(boost_path_c, "r") as f:
#                content = f.read()
#            if "#include \"filesys.h\"" not in content:
#                with open(boost_path_c, "w") as f:
#                    f.write(content.replace("#include \"lists.h\"", "#include \"lists.h\"\n#include \"filesys.h\""))

#    def edit(self, spec, prefix):
#        tty.msg(">>> Running custom edit phase for Boost patching")
#        # Other edit logic...
#    
#        if spec.satisfies("%gcc@14:"):
#            build_sh = join_path(
#                self.stage.source_path,
#                "ThirdParty", "boost", "tools", "build", "src", "engine", "build.sh"
#            )
#            if os.path.exists(build_sh):
#                from llnl.util.filesystem import FileFilter
#                ff = FileFilter(build_sh)
#                ff.filter(
#                    r'^BOOST_JAM_CC=gcc$',
#                    'BOOST_JAM_CC="gcc -Wno-error=implicit-function-declaration"'
#                )

#    @run_before("cmake")
#    def patch_boost_for_gcc14(self):
#        spec = self.spec
#    
#        if spec.satisfies("%gcc@14:"):
#            boost_build_sh = join_path(
#                self.stage.source_path,
#                "ThirdParty", "boost", "tools", "build", "src", "engine", "build.sh"
#            )
#    
#            if os.path.exists(boost_build_sh):
#                ff = FileFilter(boost_build_sh)
#                patched = ff.filter(
#                    r'^BOOST_JAM_CC=gcc$',
#                    'BOOST_JAM_CC="gcc -Wno-error=implicit-function-declaration"'
#                )
#                if patched:
#                    tty.msg("✅ Patched Boost build.sh for GCC 14")
#                else:
#                    tty.warn("⚠️ BOOST_JAM_CC=gcc not found — no patch applied.")
#            else:
#                tty.die(f"❌ Boost build.sh not found: {boost_build_sh}")
#
#    @run_before("build")
#    def patch_boost_build_script(self):
#        if self.spec.satisfies("%gcc@14:"):
#            boost_build_sh = join_path(
#                self.stage.source_path,
#                "ThirdParty", "boost", "tools", "build", "src", "engine", "build.sh"
#            )
#    
#            if os.path.exists(boost_build_sh):
#    
#                ff = FileFilter(boost_build_sh)
#                patched = ff.filter(
#                    r'^\s*echo_run\s+\$\{BOOST_JAM_CC\}\s+\$\{BOOST_JAM_OPT_JAM\}\s+\$\{BJAM_SOURCES\}',
#                    'echo_run gcc -Wno-error=implicit-function-declaration ${BOOST_JAM_OPT_JAM} ${BJAM_SOURCES}'
#                )
#    
#                if patched:
#                    tty.msg("✅ Overrode Boost jam0 compiler call with custom gcc + flag")
#                else:
#                    tty.warn("⚠️ echo_run call for jam0 not patched.")
#            else:
#                tty.warn(f"❌ Boost build.sh not found: {boost_build_sh}")


#    def edit(self, spec, prefix):
#        boost_cmake = join_path(self.stage.source_path, "cmake", "ThirdPartyBoost.cmake")
#    
#        if not os.path.exists(boost_cmake):
#            tty.warn(f"❌ Cannot find {boost_cmake} to patch Boost flags.")
#            return
#    
#        ff = FileFilter(boost_cmake)
#    
#        # Inject flag into cxxflags
#        ff.filter(
#            r'cxxflags="[^"]*',
#            lambda m: m.group(0) + ' -Wno-error=implicit-function-declaration'
#        )
#    
#        # Inject flag into cflags
#        ff.filter(
#            r'cflags="[^"]*',
#            lambda m: m.group(0) + ' -Wno-error=implicit-function-declaration'
#        )
#    
#        tty.msg("✅ Patched ThirdPartyBoost.cmake to disable -Werror=implicit-function-declaration for GCC 14+")



    def cmake_args(self):
        spec = self.spec
        args = []

        def hasfeature(feature):
            return 'ON' if feature in self.spec else 'OFF'

        args.append('-DNEKTAR_USE_FFTW=ON')
        args.append('-DNEKTAR_USE_ARPACK=ON')
        args.append('-DNEKTAR_USE_HDF5=ON')
        args.append('-DNEKTAR_ERROR_ON_WARNINGS=OFF')

        args.append('-DNEKTAR_USE_MPI=%s' % hasfeature('+mpi'))
        # args.append('-DNEKTAR_USE_FFTW=%s' % hasfeature('+fftw'))
        # args.append('-DNEKTAR_USE_ARPACK=%s' % hasfeature('+arpack'))
        # args.append('-DNEKTAR_USE_HDF5=%s' % hasfeature('+hdf5'))
        args.append('-DNEKTAR_USE_SCOTCH=%s' % hasfeature('+scotch'))
        args.append('-DNEKTAR_ENABLE_SIMD_AVX2=%s' % hasfeature('+avx2'))
        args.append('-DNEKTAR_USE_PETSC=OFF')
        args.append('-DNEKTAR_BUILD_UNIT_TESTS=%s' % hasfeature('+unit-tests'))
        args.append('-DNEKTAR_BUILD_TESTS=%s' % hasfeature('+regression-tests'))
        args.append('-DNEKTAR_BUILD_TIMINGS=%s' % hasfeature('+benchmarking-tests'))
        args.append('-DNEKTAR_BUILD_PYTHON=%s' % hasfeature('+python'))

        return args
