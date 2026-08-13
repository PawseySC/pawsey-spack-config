from spack.package import *
import os
import shutil


class Trilinos(CMakePackage, CudaPackage, ROCmPackage):
    # ...

    def patch(self):
        super().patch()

        if "+python" in self.spec and "+rocm" in self.spec:
            src = os.path.join(
                os.path.dirname(__file__),
                "fix_rocm_binder_output.py",
            )

            dst = join_path(
                self.stage.source_path,
                "packages",
                "PyTrilinos2",
                "scripts",
                "fix_rocm_binder_output.py",
            )

            shutil.copy2(src, dst)
