# just added a version 
##########################################
# Copyright 2013-2023 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
import platform
import re

import llnl.util.tty as tty

from spack.package import *

# - vanilla CentOS 7, and possibly other systems, fail a test:
#   TestCloneNEWUSERAndRemapRootDisableSetgroups
#
#   The Fix, discussed here: https://github.com/golang/go/issues/16283
#   is to enable "user_namespace".
#
#   On a Digital Ocean image, this can be achieved by updating
#   `/etc/default/grub` so that the `GRUB_CMDLINE_LINUX` variable
#   includes `user_namespace.enable=1`, re-cooking the grub
#   configuration with `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`,
#   and then rebooting.
#
# - on CentOS 7 systems (and possibly others) you need to have the
#   glibc package installed or various static cgo tests fail.
#
# - When building on a *large* machine (144 cores, 1.5TB RAM) I need
#   to run `ulimit -u 8192` to bump up the max number of user processes.
#   Failure to do so results in an explosion in one of the tests and an
#   epic stack trace....


class Go(Package):
    """The golang compiler and build environment"""

    homepage = "https://golang.org"
    url = "https://dl.google.com/go/go1.16.6.src.tar.gz"
    git = "https://go.googlesource.com/go.git"

    extendable = True
    executables = ["^go$"]

    maintainers = ["alecbcs"]

    version("1.20.4", sha256="9f34ace128764b7a3a4b238b805856cc1b2184304df9e5690825b0710f4202d6")
    version("1.20.3", sha256="e447b498cde50215c4f7619e5124b0fc4e25fb5d16ea47271c47f278e7aa763a")

    version("1.19.10", sha256="13755bcce529747d5f2930dee034730c86d02bd3e521ab3e2bbede548d3b953f")
    version("1.19.9", sha256="131190a4697a70c5b1d232df5d3f55a3f9ec0e78e40516196ffb3f09ae6a5744")
    version("1.19.8", sha256="1d7a67929dccafeaf8a29e55985bc2b789e0499cb1a17100039f084e3238da2f")

    # Deprecated Versions
    # https://nvd.nist.gov/vuln/detail/CVE-2023-24538
    version(
        "1.20.2",
        sha256="4d0e2850d197b4ddad3bdb0196300179d095bb3aefd4dfbc3b36702c3728f8ab",
        deprecated=True,
    )
    version(
        "1.19.7",
        sha256="775bdf285ceaba940da8a2fe20122500efd7a0b65dbcee85247854a8d7402633",
        deprecated=True,
    )

    # https://nvd.nist.gov/vuln/detail/CVE-2023-24532
    version(
        "1.20.1",
        sha256="b5c1a3af52c385a6d1c76aed5361cf26459023980d0320de7658bae3915831a2",
        deprecated=True,
    )
    # https://nvd.nist.gov/vuln/detail/CVE-2022-41723
    version(
        "1.20",
        sha256="3a29ff0421beaf6329292b8a46311c9fbf06c800077ceddef5fb7f8d5b1ace33",
        deprecated=True,
    )
    # https://nvd.nist.gov/vuln/detail/CVE-2022-41725
    version(
        "1.19.6",
        sha256="d7f0013f82e6d7f862cc6cb5c8cdb48eef5f2e239b35baa97e2f1a7466043767",
        deprecated=True,
    )
    # https://nvd.nist.gov/vuln/detail/CVE-2022-41725
    version(
        "1.19.5",
        sha256="8e486e8e85a281fc5ce3f0bedc5b9d2dbf6276d7db0b25d3ec034f313da0375f",
        deprecated=True,
    )
    version(
        "1.19.4",
        sha256="eda74db4ac494800a3e66ee784e495bfbb9b8e535df924a8b01b1a8028b7f368",
        deprecated=True,
    )
    # https://nvd.nist.gov/vuln/detail/CVE-2022-41724
    version(
        "1.18.10",
        sha256="9cedcca58845df0c9474ae00274c44a95c9dfaefb132fc59921c28c7c106f8e6",
        deprecated=True,
    )
    version(
        "1.18.9",
        sha256="fbe7f09b96aca3db6faeaf180da8bb632868ec049731e355ff61695197c0e3ea",
        deprecated=True,
    )

    provides("golang")

    depends_on("git", type=("build", "link", "run"))

    # aarch64 machines (including Macs with Apple silicon) can't use
    # go-bootstrap because it pre-dates aarch64 support in Go.  These machines
    # have to rely on Go support in gcc (which may require compiling a version
    # of gcc with Go support just to satisfy this requirement) or external go:

    # #27769: On M1/MacOS, platform.machine() may return arm64:
    if platform.machine() in ["arm64", "aarch64"]:
        # Use an external go compiler from packages.yaml/`spack external find go-bootstrap`,
        # but fallback to build go-bootstrap@1.4 or to gcc with languages=go (for aarch64):
        depends_on("go-external-or-gccgo-bootstrap", type="build")
    else:
        depends_on("go-bootstrap", type="build")

    # https://github.com/golang/go/issues/17545
    patch("time_test.patch", when="@1.6.4:1.7.4")

    # https://github.com/golang/go/issues/17986
    # The fix for this issue has been merged into the 1.8 tree.
    patch("misc-cgo-testcshared.patch", level=0, when="@1.6.4:1.7.5")

    # Unrecognized option '-fno-lto'
    conflicts("%gcc@:4", when="@1.17:")

    @classmethod
    def determine_version(cls, exe):
        output = Executable(exe)("version", output=str, error=str)
        match = re.search(r"go version go(\S+)", output)
        return match.group(1) if match else None

    # NOTE: Older versions of Go attempt to download external files that have
    # since been moved while running the test suite.  This patch modifies the
    # test files so that these tests don't cause false failures.
    # See: https://github.com/golang/go/issues/15694
    @when("@:1.4.3")
    def patch(self):
        test_suite_file = FileFilter(join_path("src", "run.bash"))
        test_suite_file.filter(
            r"^(.*)(\$GOROOT/src/cmd/api/run.go)(.*)$",
            r"# \1\2\3",
        )

    def install(self, spec, prefix):
        bash = which("bash")

        wd = "."

        # 1.11.5 directory structure is slightly different
        if self.version == Version("1.11.5"):
            wd = "go"

        with working_dir(join_path(wd, "src")):
            bash("{0}.bash".format("all" if self.run_tests else "make"))

        install_tree(wd, prefix)

    def setup_build_environment(self, env):
        env.set("GOROOT_FINAL", self.spec.prefix)
        # We need to set CC/CXX_FOR_TARGET, otherwise cgo will use the
        # internal Spack wrappers and fail.
        env.set("CC_FOR_TARGET", self.compiler.cc)
        env.set("CXX_FOR_TARGET", self.compiler.cxx)

    def setup_dependent_package(self, module, dependent_spec):
        """Called before go modules' install() methods.

        In most cases, extensions will only need to set GOPATH and use go::

        env['GOPATH'] = self.source_path + ':' + env['GOPATH']
        go('get', '<package>', env=env)
        install_tree('bin', prefix.bin)
        """
        #  Add a go command/compiler for extensions
        module.go = self.spec["go"].command

    def generate_path_components(self, dependent_spec):
        if os.environ.get("GOROOT", False):
            tty.warn("GOROOT is set, this is not recommended")

        # Set to include paths of dependencies
        path_components = [dependent_spec.prefix]
        for d in dependent_spec.traverse():
            if d.package.extends(self.spec):
                path_components.append(d.prefix)
        return ":".join(path_components)

    def setup_dependent_build_environment(self, env, dependent_spec):
        # This *MUST* be first, this is where new code is installed
        env.prepend_path("GOPATH", self.generate_path_components(dependent_spec))

    def setup_dependent_run_environment(self, env, dependent_spec):
        # Allow packages to find this when using module files
        env.prepend_path("GOPATH", self.generate_path_components(dependent_spec))
