
# define the installation path 
if [ ! -z ${AMBER_INSTALL_DIR} ]
then 
  export AMBER_INSTALL_DIR="/software/setonix/${DATE_TAG}/custom/software/zen3/gcc/12.1.0/amber/2022"
  export AMBER_SOURCE_DIR="/tmp/amber-build"
fi

echo "This script should not be run as it requires an interactive ccmake session."
echo "Instead source this to define bash functions that will help with the installation."
echo "These might need updates depending on the modules that are available on the system"
echo "Installation to these macros will install stuff to ${AMBER_INSTALL_DIR}" 
echo "tarball will be unpacked to ${AMBER_SOURCE_DIR}" 
echo "If that is not desired, please change AMBER_INSTALL_DIR"
echo "COMMANDS to run in order"
echo "amber_unpack_tarball <path/to/amber.tgz>"
echo "amber_load_dependencies"
echo "amber_generate_pyvenv"
echo "amber_run_initial_cmake"
echo "amber_run_ccmake"
echo "amber_install"
echo "amber_check_install"
echo "amber_install_module"

function amber_report_paths
{
  echo "Paths are ${AMBER_SOURCE_DIR} and ${AMBER_INSTALL_DIR}"
}

# now unpack the source in /tmp on the node and build it, installing it to the appropriate path 
function amber_unpack_tarball 
{
  amber_tarball=$1
  tar xf ${amber_tarball} -C ${AMBER_SOURCE_DIR}
}


# load the modules
# note that this list might require updates as modules change 
function amber_load_dependences
{
  modlist=(\
  "py-setuptools/59.4.0-py3.10.10" \
  "py-numpy/1.23.4" \
  "py-scipy/1.8.1" \
  "py-matplotlib/3.6.2" \
  "perl/5.36.0" \
  "cmake/3.24.3" \
  "netcdf-fortran/4.6.0" \
  "openblas/0.3.21" \
  "boost/1.80.0-c++98-python" \
  "fftw/3.3.10" \
  "arpack-ng/3.8.0" \
  "plumed/2.9.0" \
  )
  # load the modules 
  for m in ${modlist[@]}; do module load ${m}; done 
}

# now to a pip install of tk in a virtual environment as this is the easiest option
# by which to install this package (doesn't have a spack recipe)
function amber_generate_pyvenv
{
  python -m venv ${AMBER_INSTALL_DIR}/py-for-amber
  source ${AMBER_INSTALL_DIR}/py-for-amber/bin/activate
  pip install --upgrade pip
  pip install tk
  deactivate
}

# make own build dir as one that comes with repo filled with stuff 
function amber_run_initial_cmake
{
  cd ${AMBER_SOURCE_DIR}
  mkdir -p build2
  cd build2
  source ${AMBER_INSTALL_DIR}/py-for-amber/bin/activate
  cmakeargs="\
  -DCMAKE_CXX_COMPILER=CC \
  -DCMAKE_C_COMPILER=cc \
  -DCMAKE_Fortran_COMPILER=ftn \
  -DCOMPILER=GNU \
  -DDOWNLOAD_MINICONDA=FALSE \
  -DHAVE_NUMPY=ON \
  -DHAVE_SCIPY=ON \
  -DHAVE_MATPLOTLIB=ON \
  -DMPI=ON \
  -DOPENMP=ON \
  -DHAVE_TKINTER=ON \
  -DCMAKE_INSTALL_PREFIX=${AMBER_INSTALL_DIR} \
  "
  cmake ../ ${cmakeargs}
  deactivate
}

# cmake fails first time around run again but do it in ccmake and just configure and generate 
function amber_run_ccmake
{
  source ${AMBER_INSTALL_DIR}/py-for-amber/bin/activate
  cd ${AMBER_SOURCE_DIR}/build2
  ccmake -DHAVE_TKINTER=ON . 
  deactivate
}

# now compile and install 
function amber_install
{
  source ${AMBER_INSTALL_DIR}/py-for-amber/bin/activate
  cd ${AMBER_SOURCE_DIR}/build2
  make -j64
  make -j16 install
  deactivate
}

# since amber builds lots of packages, here is a list of what should be expected 
function amber_check_install
{
  execlist=(\
  addles \
  add_pdb \
  AddToBox \
  add_xray \
  am1bcc \
  amb2chm_par.py \
  amb2chm_psf_crd.py \
  amb2gro_top_gro.py \
  ambmask \
  ambpdb \
  antechamber \
  ante-MMPBSA.py \
  atomtype \
  bar_pbsa.py \
  bondtype \
  CartHess2FC.py \
  car_to_files.py \
  ceinutil.py \
  cestats \
  charmmlipid2amber.py \
  ChBox \
  cpeinutil.py \
  cphstats \
  cpinutil.py \
  cpptraj \
  cpptraj.MPI \
  cpptraj.OMP \
  draw_membrane2 \
  edgembar \
  edgembar-amber2dats.py \
  edgembar.OMP \
  edgembar-WriteGraphHtml.py \
  elsize \
  espgen \
  espgen.py \
  FEW.pl \
  finddgref.py \
  fitpkaeo.py \
  fixremdcouts.py \
  gbnsr6 \
  gem.pmemd \
  gem.pmemd.MPI \
  genremdinputs.py \
  gwh \
  hcp_getpdb \
  IPMach.py \
  makeANG_RST \
  makeCHIR_RST \
  make_crd_hg \
  makeCSA_RST.na \
  makeDIP_RST.dna \
  makeDIP_RST.protein \
  makeDIST_RST \
  makeRIGID_RST \
  MCPB.py \
  mdgx \
  mdgx.MPI \
  mdgx.OMP \
  mdout2pymbar.pl \
  mdout_analyzer.py \
  memembed \
  metalpdb2mol2.py \
  metatwist \
  mm_pbsa_nabnmode \
  mm_pbsa.pl \
  MMPBSA.py \
  mmpbsa_py_energy \
  MMPBSA.py.MPI \
  mmpbsa_py_nabnmode \
  mm_pbsa_statistics.pl \
  mol2rtf.py \
  ndfes \
  ndfes-AvgFESs.py \
  ndfes-CheckEquil.py \
  ndfes-CombineMetafiles.py \
  ndfes-FTSM-PrepareAnalysis.py \
  ndfes-FTSM-PrepareGuess.py \
  ndfes-FTSM-PrepareSims.py \
  ndfes.OMP \
  ndfes-PrepareAmberData.py \
  ndfes-PrintFES.py \
  ndfes-PrintStringFES.py \
  nef_to_RST \
  nf-config \
  nfe-umbrella-slice \
  nmode \
  OptC4.py \
  packmol \
  packmol-memgen \
  paramfit \
  paramfit.OMP \
  parmcal \
  parmchk2 \
  parmed \
  pbsa \
  pdb4amber \
  PdbSearcher.py \
  pmemd \
  pmemd.MPI \
  prepgen \
  process_mdout.perl \
  process_minout.perl \
  PropPDB \
  ProScrs.py \
  pyresp_gen.py \
  py_resp.py \
  quick \
  quick.MPI \
  reduce \
  residuegen \
  resp \
  respgen \
  rism1d \
  rism3d.orave \
  rism3d.snglpnt \
  rism3d.snglpnt.MPI \
  rism3d.thermo \
  sander \
  sander.LES \
  sander.LES.MPI \
  sander.MPI \
  sander.OMP \
  saxs_md \
  saxs_md.OMP \
  saxs_rism \
  saxs_rism.OMP \
  senergy \
  sgldinfo.sh \
  sgldwt.sh \
  simplepbsa \
  simplepbsa.MPI \
  softcore_setup.py \
  sqm \
  sqm.MPI \
  sviol \
  sviol2 \
  teLeap \
  test-api \
  test-api.MPI \
  tinker_to_amber \
  tleap \
  ucpp \
  UnitCell \
  XrayPrep
  wrapped_progs/am1bcc \
  wrapped_progs/antechamber \
  wrapped_progs/atomtype \
  wrapped_progs/bondtype \
  wrapped_progs/espgen \
  wrapped_progs/parmcal \
  wrapped_progs/parmchk2 \
  wrapped_progs/prepgen \
  wrapped_progs/reduce \
  wrapped_progs/residuegen \
  wrapped_progs/respgen \
  )

  # can also run this check to see if installation is okay 
  for f in ${execlist[@]}
  do
    if [ ! -f ${AMBER_INSTALL_DIR}/bin/${f} ]
    then
      echo "Installation warning, missing ${f}"
    fi 
  done
}

function amber_install_module
{
  echo "Still in progress ..."
}