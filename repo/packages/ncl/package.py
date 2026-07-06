# Copyright 2013-2023 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import glob
import os
import tempfile

from spack.package import *


class Ncl(Package):
    """NCL is an interpreted language designed specifically for
    scientific data analysis and visualization. Supports NetCDF 3/4,
    GRIB 1/2, HDF 4/5, HDF-EOS 2/5, shapefile, ASCII, binary.
    Numerous analysis functions are built-in."""

    homepage = "https://www.ncl.ucar.edu"
    git = "https://github.com/NCAR/ncl.git"
    url = "https://github.com/NCAR/ncl/archive/6.4.0.tar.gz"

    maintainers("vanderwb")

    version("6.6.2", sha256="cad4ee47fbb744269146e64298f9efa206bc03e7b86671e9729d8986bb4bc30e")
    version("6.5.0", sha256="133446f3302eddf237db56bf349e1ebf228240a7320699acc339a3d7ee414591")
    version("6.4.0", sha256="0962ae1a1d716b182b3b27069b4afe66bf436c64c312ddfcf5f34d4ec60153c8")

    patch("for_aarch64.patch", when="target=aarch64:")

    # Use Spack config file, generated during installation.
    patch("set_spack_config.patch")

    # Make ncl compile with hdf5 1.10.
    patch("hdf5.patch", when="@6.4.0")

    # ymake-filter's buffer may overflow.
    patch("ymake-filter.patch", when="@6.4.0")

    # ymake additional local library/includes handling.
    #
    # Do not replace '-Dlinux=linux -Dx86_64=x86_64' with '-Ulinux -Ux86_64'.
    # The old NCL/ymake build system depends on those macros being defined.
    patch("ymake.patch", when="@6.4.0:")

    # Old NCL code needs this with modern GCC.
    # Apply unconditionally because Setonix compiler aliases such as
    # %gcc_compiler or none-none may not match normal %gcc@10:.
    patch(
        "https://src.fedoraproject.org/rpms/ncl/raw/12778c55142b5b1ccc26dfbd7857da37332940c2/f/ncl-boz.patch",
        sha256="64f3502c9deab48615a4cbc26073173081c0774faf75778b044d251e45d238f7",
    )

    # g2clib does not have a ymakefile. This patch avoids a benign ymake error.
    patch("ymake-grib.patch", when="+grib")

    variant("hdf4", default=False, description="Enable HDF4 support.")
    variant("gdal", default=False, description="Enable GDAL support.")
    variant("triangle", default=True, description="Enable Triangle support.")
    variant("udunits2", default=True, description="Enable UDUNITS-2 support.")
    variant("openmp", default=True, description="Enable OpenMP support.")
    variant("grib", default=True, description="Enable GRIB support.")

#    depends_on("c", type="build")
#    depends_on("cxx", type="build")
#    depends_on("fortran", type="build")

    # Core dependencies
    depends_on("jpeg")
    depends_on("libpng")
    depends_on("zlib")
    depends_on("netcdf-c")
    depends_on("cairo+X+ft+pdf")

    # Build tools
    depends_on("gmake", type="build")
    depends_on("bison", type="build")
    depends_on("flex+lex")
    depends_on("tcsh")
    depends_on("makedepend", type="build")

    # X / graphics / compression dependencies
    depends_on("curl")
    depends_on("iconv")
    depends_on("expat")
    depends_on("libx11")
    depends_on("libxt")
    depends_on("libsm")
    depends_on("libice")
    depends_on("libxaw")
    depends_on("libxmu")
    depends_on("libxext")
    depends_on("libxrender")
    depends_on("pixman")
    depends_on("bzip2")
    depends_on("freetype")
    depends_on("fontconfig")
    depends_on("zstd")

    # NetCDF4/HDF5 support
    depends_on("hdf5+szip")
    depends_on("szip")

    # ESMF is runtime only
    depends_on("esmf+netcdf", type="run")

    # Optional dependencies
    depends_on("hdf", when="+hdf4")
    depends_on("gdal@:2.4", when="+gdal")
    depends_on("udunits", when="+udunits2")
    depends_on("jasper@2.0.32", when="+grib")

    resource(
        name="triangle",
        url="https://www.netlib.org/voronoi/triangle.zip",
        sha256="1766327add038495fa3499e9b7cc642179229750f7201b94f8e1b7bee76f8480",
        placement="triangle_src",
        when="+triangle",
    )

    sanity_check_is_file = ["bin/ncl"]

    def patch(self):
        # Make configure scripts use Spack's tcsh.
        files = ["Configure"] + glob.glob("config/*")
        filter_file("^#!/bin/csh -f", "#!/usr/bin/env csh", *files)

        # GRIB/g2clib fixes.
        if "+grib" in self.spec:
            filter_file("image.inmem_=1;", "", "external/g2clib-1.6.0/enc_jpeg2000.c")

            filter_file(
                "SUBDIRS = ",
                "SUBDIRS = g2clib-1.6.0 ",
                "external/yMakefile",
            )

            # Important: must be -I<jasper-include>, not the raw include path.
            # Otherwise GCC treats the include directory as an input file and
            # dec_jpeg2000.c cannot find jasper/jasper.h.
            filter_file(
                r"INC=.*",
                "INC=-I%s" % self.spec["jasper"].prefix.include,
                "external/g2clib-1.6.0/makefile",
            )

        # ictrans has an all-local target that does:
        #     cat Copyright
        # but the Copyright file is not always present.
        filter_file(
            r"@\$\(CAT\) Copyright",
            r"@test ! -f Copyright || $(CAT) Copyright",
            "ncarview/src/bin/ictrans/yMakefile",
        )

    @run_before("install")
    def filter_sbang(self):
        files = glob.glob("ncarg2d/src/bin/scripts/*")
        files += glob.glob("ncarview/src/bin/scripts/*")
        files += glob.glob("ni/src/scripts/*")

        csh = join_path(self.spec["tcsh"].prefix.bin, "csh")
        filter_file("^#!/bin/csh", "#!{0}".format(csh), *files)

    def install(self, spec, prefix):
        local_libs, local_includes = self.local_paths()

        compiler_wrapper_dir = self.create_compiler_wrappers(local_libs)
        install_wrapper = self.create_install_wrapper()

        old_path = os.environ["PATH"]
        os.environ["PATH"] = compiler_wrapper_dir + os.pathsep + old_path

        try:
            self.prepare_site_config(install_wrapper)
            self.prepare_install_config(local_libs, local_includes)
            self.prepare_src_tree()

            make("Everything", parallel=False)

        finally:
            os.environ["PATH"] = old_path

        if not os.path.isdir(self.spec.prefix.bin):
            raise RuntimeError("Installation failed: prefix/bin was not created")

        if "ncl" not in os.listdir(self.spec.prefix.bin):
            raise RuntimeError("Installation failed: ncl executable was not created")

#    def install(self, spec, prefix):
#        local_libs, local_includes = self.local_paths()
#
#        compiler_wrapper_dir = self.create_compiler_wrappers(local_libs)
#        install_wrapper = self.create_install_wrapper()
#
#        saved_env = {}
#        env_vars = [
#            "PATH",
#            "CC",
#            "CXX",
#            "FC",
#            "F77",
#            "F90",
#            "CPP",
#            "CFLAGS",
#            "CXXFLAGS",
#            "FFLAGS",
#            "FCFLAGS",
#            "LDFLAGS",
#        ]
#
#        for var in env_vars:
#            saved_env[var] = os.environ.get(var)
#
#        # Put our wrappers first.
#        os.environ["PATH"] = compiler_wrapper_dir + os.pathsep + saved_env["PATH"]
#
#        # Avoid Spack's compiler-wrapper being picked up by NCL Configure.
#        os.environ["CC"] = "cc"
#        os.environ["CXX"] = "CC"
#        os.environ["FC"] = "ftn"
#        os.environ["F77"] = "ftn"
#        os.environ["F90"] = "ftn"
#
#        # Avoid old Configure inheriting Spack flags in unexpected places.
#        for var in ["CPP", "CFLAGS", "CXXFLAGS", "FFLAGS", "FCFLAGS", "LDFLAGS"]:
#            os.environ.pop(var, None)
#
#        try:
#            self.prepare_site_config(install_wrapper)
#            self.prepare_install_config(local_libs, local_includes)
#            self.prepare_src_tree()
#
#            make("Everything", parallel=False)
#
#        finally:
#            for var, value in saved_env.items():
#                if value is None:
#                    os.environ.pop(var, None)
#                else:
#                    os.environ[var] = value
#
#        if not os.path.isdir(self.spec.prefix.bin):
#            raise RuntimeError("Installation failed: prefix/bin was not created")
#
#        if "ncl" not in os.listdir(self.spec.prefix.bin):
#            raise RuntimeError("Installation failed: ncl executable was not created")


    def setup_run_environment(self, env):
        env.set("NCARG_ROOT", self.spec.prefix)
        env.set("ESMFBINDIR", self.spec["esmf"].prefix.bin)

    def create_compiler_wrappers(self, local_libs):
        """Create wrappers around Cray compiler wrappers.

        NCL's old ymake files sometimes put dependency libraries before
        dependency -L paths. Injecting -L paths through wrappers makes them
        visible before any -l flags.

        Also inject -std=gnu99 for C compiles. Some NCL 6.6.2 sources use
        C99 loop declarations, but the old build system may otherwise compile
        them as GNU89.
        """

        wrapper_dir = join_path(self.stage.source_path, "spack-compiler-wrappers")
        mkdirp(wrapper_dir)

        real_cc = which("cc", required=True).path
        real_cxx = which("CC", required=True).path
        real_ftn = which("ftn", required=True).path

        lib_flags = " ".join("-L{0}".format(d) for d in local_libs)

        c_flags = " ".join(
            [
                "-std=gnu99",
                "-fcommon",
                "-Wno-error=incompatible-pointer-types",
                "-Wno-error=implicit-function-declaration",
                "-Wno-error=implicit-int",
                "-Wno-error=int-conversion",
                "-Wno-implicit-function-declaration",
                "-Wno-implicit-int",
                "-Wno-int-conversion",
                "-Wno-incompatible-pointer-types",
            ]
        )

        wrappers = {
            # Cray compiler wrappers used explicitly by config/Spack
            "cc": (real_cc, c_flags),
            "CC": (real_cxx, ""),
            "ftn": (real_ftn, ""),

            # Legacy compiler names used by NCL/g2clib build files
            "gcc": (real_cc, c_flags),
            "g++": (real_cxx, ""),
            "c++": (real_cxx, ""),
            "f77": (real_ftn, ""),
            "f90": (real_ftn, ""),
            "gfortran": (real_ftn, ""),
        }

        for name, target_and_flags in wrappers.items():
            target, extra_flags = target_and_flags
            wrapper = join_path(wrapper_dir, name)

            if os.path.exists(wrapper):
                os.remove(wrapper)

            all_flags = " ".join(x for x in [extra_flags, lib_flags] if x)

            with open(wrapper, "w") as f:
                f.write("#!/bin/sh\n")
                if all_flags:
                    f.write('exec "{0}" {1} "$@"\n'.format(target, all_flags))
                else:
                    f.write('exec "{0}" "$@"\n'.format(target))

            os.chmod(wrapper, 0o755)

        return wrapper_dir

    def create_install_wrapper(self):
        # Do not put /usr/bin/install directly into config/Spack.
        # NCL's ymake preprocessing can mangle install-like paths.
        wrapper_dir = join_path(self.stage.source_path, "spack-ncl-tools")
        mkdirp(wrapper_dir)

        wrapper = join_path(wrapper_dir, "nclcopy")

        if os.path.exists(wrapper):
            os.remove(wrapper)

        with open(wrapper, "w") as f:
            f.write("#!/bin/sh\n")
            f.write('exec /usr/bin/install "$@"\n')

        os.chmod(wrapper, 0o755)

        return wrapper

    def prepare_site_config(self, install_wrapper):
        fc_flags = []
        cc_flags = []
        c2f_flags = []

        if "+openmp" in self.spec:
            fc_flags.append("-fopenmp")
            cc_flags.append("-fopenmp")

        if self.spec.satisfies("^hdf5@1.11:"):
            cc_flags.append("-DH5_USE_110_API")

        # Apply these unconditionally for this Setonix/Pawsey build.
        # The spec shows none-none for ncl, so normal compiler constraints
        # like %gcc@10: may not trigger reliably.
        fc_flags.append("-fno-range-check")
        fc_flags.append("-fallow-argument-mismatch")

        cc_flags.append("-std=gnu99")
        cc_flags.append("-fcommon")
        cc_flags.append("-Wno-error=incompatible-pointer-types")
        cc_flags.append("-Wno-error=implicit-function-declaration")
        cc_flags.append("-Wno-error=implicit-int")
        cc_flags.append("-Wno-error=int-conversion")
        cc_flags.append("-Wno-implicit-function-declaration")
        cc_flags.append("-Wno-implicit-int")
        cc_flags.append("-Wno-int-conversion")
        cc_flags.append("-Wno-incompatible-pointer-types")

        c2f_flags.extend(["-lgfortran", "-lquadmath", "-lgomp", "-lm"])

        if self.spec.satisfies("+grib"):
            gribline = (
                "#define GRIB2lib %s/external/g2clib-1.6.0/libgrib2c.a "
                "-ljasper -lpng -lz -ljpeg\n"
                % self.stage.source_path
            )
        else:
            gribline = ""

        with open("./config/Spack", "w") as f:
            f.writelines(
                [
                    "#define HdfDefines\n",
                    "#define CppCommand '/usr/bin/env cpp -traditional'\n",

                    # Cray wrappers. PATH is prepended with our wrapper dir.
                    "#define CCompiler cc\n",
                    "#define CxxCompiler CC\n",
                    "#define CLoader cc\n",
                    "#define FCompiler ftn\n",
                    "#define FLoader ftn\n",
                    "#define F77Compiler ftn\n",
                    "#define F90Compiler ftn\n",

                    "#ifdef InstallCommand\n",
                    "#undef InstallCommand\n",
                    "#endif\n",
                    "#define InstallCommand {0}\n".format(install_wrapper),

                    "#define CtoFLibraries " + " ".join(c2f_flags) + "\n",
                    "#define CtoFLibrariesUser " + " ".join(c2f_flags) + "\n",
                    "#define CcOptions " + " ".join(cc_flags) + "\n",
                    "#define FcOptions " + " ".join(fc_flags) + "\n",

                    "#define BuildShared NO\n",
                    gribline,
                ]
            )

    def prepare_install_config(self, local_libs, local_includes):
        self.delete_files("./Makefile", "./config/Site.local")

        config_answers = [
            # Enter Return to continue
            "\n",

            # Build NCL?
            "y\n",

            # Parent installation directory
            self.spec.prefix + "\n",

            # System temp space directory
            tempfile.gettempdir() + "\n",

            # Build NetCDF4 feature support?
            "y\n",
        ]

        if "+hdf4" in self.spec:
            config_answers.extend(
                [
                    # Build HDF4 support into NCL?
                    "y\n",

                    # Also build HDF4 support into raster library?
                    "y\n",

                    # Did you build HDF4 with szip support?
                    "y\n" if self.spec.satisfies("^hdf+szip") else "n\n",
                ]
            )
        else:
            config_answers.extend(
                [
                    # Build HDF4 support into NCL?
                    "n\n",

                    # Also build HDF4 support into raster library?
                    "n\n",
                ]
            )

        config_answers.extend(
            [
                # Build Triangle support into NCL?
                "y\n" if "+triangle" in self.spec else "n\n",

                # If using NetCDF V4.x, did you enable NetCDF-4 support?
                "y\n",

                # Did you build NetCDF with OPeNDAP support?
                "y\n" if self.spec.satisfies("^netcdf-c+dap") else "n\n",

                # Build GDAL support into NCL?
                "y\n" if "+gdal" in self.spec else "n\n",

                # Build EEMD support into NCL?
                "n\n",

                # Build Udunits-2 support into NCL?
                "y\n" if "+udunits2" in self.spec else "n\n",

                # Build Vis5d+ support into NCL?
                "n\n",

                # Build HDF-EOS2 support into NCL?
                "n\n",

                # Build HDF5 support into NCL?
                "y\n",

                # Build HDF-EOS5 support into NCL?
                "n\n",

                # Build GRIB2 support into NCL?
                "y\n" if self.spec.satisfies("+grib") else "n\n",

                # Enter local library search path(s)
                " ".join(local_libs) + "\n",

                # Enter local include search path(s)
                " ".join(local_includes) + "\n",

                # Go back and make more changes or review?
                "n\n",

                # Save current configuration?
                "y\n",
            ]
        )

        config_answers_filename = "spack-config.in"
        config_script = Executable("./Configure")

        with open(config_answers_filename, "w") as f:
            f.writelines(config_answers)

        with open(config_answers_filename, "r") as f:
            config_script(input=f)

        if self.spec.satisfies("^hdf+external-xdr") and not self.spec["hdf"].satisfies("^libc"):
            hdf4 = self.spec["hdf"]

            filter_file(
                "(#define HDFlib.*)",
                r"\1 {}".format(hdf4["rpc"].libs.link_flags),
                "config/Site.local",
            )

    def local_paths(self):
        local_libs = []
        local_includes = []

        lib_pkgs = [
            "fontconfig",
            "pixman",
            "bzip2",
            "freetype",
            "libx11",
            "libxt",
            "libxaw",
            "libxmu",
            "libxext",
            "libsm",
            "libice",
            "libxrender",
            "jpeg",
            "libpng",
            "zlib",
            "netcdf-c",
            "hdf5",
            "szip",
            "zstd",
            "curl",
            "cairo",
            "expat",
        ]

        include_pkgs = [
            "freetype",
            "fontconfig",
            "pixman",
            "libx11",
            "libxt",
            "libxaw",
            "libxmu",
            "libxext",
            "libsm",
            "libice",
            "libxrender",
            "jpeg",
            "libpng",
            "zlib",
            "netcdf-c",
            "hdf5",
            "szip",
            "zstd",
            "curl",
            "cairo",
            "expat",
        ]

        if "+udunits2" in self.spec:
            lib_pkgs.append("udunits")
            include_pkgs.append("udunits")

        if "+hdf4" in self.spec:
            lib_pkgs.append("hdf")
            include_pkgs.append("hdf")

        if "+gdal" in self.spec:
            lib_pkgs.append("gdal")
            include_pkgs.append("gdal")

        if "+grib" in self.spec:
            lib_pkgs.append("jasper")
            include_pkgs.append("jasper")

        for pkg in lib_pkgs:
            local_libs.extend(self.library_dirs(pkg))

        for pkg in include_pkgs:
            local_includes.extend(self.include_dirs(pkg))

        if "+grib" in self.spec:
            local_includes.append(join_path(self.stage.source_path, "external", "g2clib-1.6.0"))

        return self.unique_existing_dirs(local_libs), self.unique_existing_dirs(local_includes)

    def library_dirs(self, pkg):
        dirs = []

        if pkg not in self.spec:
            return dirs

        try:
            for d in self.spec[pkg].libs.directories:
                dirs.append(str(d))
        except Exception:
            pass

        for d in [
            self.spec[pkg].prefix.lib,
            self.spec[pkg].prefix.lib64,
        ]:
            dirs.append(str(d))

        return dirs

    def include_dirs(self, pkg):
        dirs = []

        if pkg not in self.spec:
            return dirs

        try:
            for d in self.spec[pkg].headers.directories:
                dirs.append(str(d))
        except Exception:
            pass

        for d in [
            self.spec[pkg].prefix.include,
            join_path(self.spec[pkg].prefix.include, "freetype2"),
            join_path(self.spec[pkg].prefix.include, "cairo"),
        ]:
            dirs.append(str(d))

        return dirs

    def prepare_src_tree(self):
        if "+triangle" in self.spec:
            triangle_src = join_path(self.stage.source_path, "triangle_src")
            triangle_dst = join_path(self.stage.source_path, "ni", "src", "lib", "hlu")
            copy(join_path(triangle_src, "triangle.h"), triangle_dst)
            copy(join_path(triangle_src, "triangle.c"), triangle_dst)

    @staticmethod
    def delete_files(*filenames):
        for filename in filenames:
            if os.path.exists(filename):
                try:
                    os.remove(filename)
                except OSError as e:
                    raise InstallError("Failed to delete file %s: %s" % (e.filename, e.strerror))

    @staticmethod
    def unique_existing_dirs(paths):
        seen = set()
        result = []

        for path in paths:
            path = str(path)
            if path and os.path.isdir(path) and path not in seen:
                seen.add(path)
                result.append(path)

        return result
