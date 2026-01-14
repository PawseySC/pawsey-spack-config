-- -*- lua -*-

whatis([[Name : NAME]])
whatis([[Short description : BRIEF ]])
whatis([[Version : VERSION ]])
whatis([[Compiler : COMPILER_VERSION]])
whatis([[Build date : BUILD_DATE]])
whatis([[Path : INSTALL_PATH ]])

help([[ DESCRIP ]])

depends_on("cuquantum/25.11.1")
depends_on("python/3.11.6")
depends_on("py-numpy/2.1.2")
depends_on("py-scipy/1.13.0")
depends_on("py-cython/3.0.11")
depends_on("py-mpi4py/3.1.5-py3.11.6")
depends_on("py-setuptools/70.1.0-py3.11.6")
family("qiskit")

local root = "INSTALL_PATH"

prepend_path("PYTHONPATH", root)

if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end
