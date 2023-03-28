#!/bin/bash
if [ -z ${__PSC_SETTINGS__+x} ]; then # include guard
__PSC_SETTINGS__=1

# EDIT at each rebuild of the software stack
DATE_TAG="2023.02"

if [ -z ${INSTALL_PREFIX+x} ]; then
    INSTALL_PREFIX="/software/setonix/${DATE_TAG}"
fi

if [ "${INSTALL_PREFIX%$DATE_TAG}" = "${INSTALL_PREFIX}" ]; then
    echo "The path in 'INSTALL_PREFIX' must end with ${DATE_TAG} but its value is ${INSTALL_PREFIX}"
    exit 1
fi

if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
    SYSTEM="$PAWSEY_CLUSTER"
fi

if [ -z ${SYSTEM+x} ]; then
    echo "The 'SYSTEM' variable is not set. Please specify the system you want to
    build Spack for."
    exit 1
fi

if [ "$USER" = "spack" ]; then
    INSTALL_GROUP="spack"
fi

if [ -z ${INSTALL_GROUP+x} ]; then
    echo "The 'INSTALL_GROUP' variable must be set to linux group that will own the installed files."
    exit 1
fi

# Note the use of '' instead of "" to allow env variables to be present in config files
USER_PERMANENT_FILES_PREFIX='/software/projects'
USER_TEMP_FILES_PREFIX='/scratch'
SPACK_USER_CONFIG_PATH="$MYSOFTWARE/setonix/$DATE_TAG/.spack_user_config"
BOOTSTRAP_PATH='$MYSOFTWARE/setonix/'$DATE_TAG/.spack_user_config/bootstrap

pawseyenv_version="${DATE_TAG}"

archs="zen2 zen3"
# compiler versions (needed for module trees with compiler dependency)
gcc_version="12.1.0"
cce_version="14.0.3"
aocc_version="3.2.0"

# architecture of login/compute nodes (needed by Singularity symlink module)
cpu_arch="zen3"

# tool versions
spack_version="0.19.0" # the prefix "v" is added in setup_spack.sh
singularity_version="3.8.6-nompi" # has to match the version in the Spack env yaml + nompi tag
singularity_mpi_version="3.8.6-mpi" # has to match the version in the Spack env yaml + mpi tag
shpc_version="0.1.18"
shpc_registry_version="55187da47fb79c6632de8a43a90a562a476106ee"

# python (and py tools) versions
python_name="python"
python_version="3.9.15" # has to match the version in the Spack env yaml
setuptools_version="57.4.0" # has to match the version in the Spack env yaml
pip_version="22.2.2" # has to match the version in the Spack env yaml
# r major minor version
r_version_majorminor="4.1"

# list of module categories
module_cat_list="
astro-applications
bio-applications
applications
libraries
programming-languages
utilities
visualisation
python-packages
benchmarking
developer-tools
dependencies
"

# list of spack build environments - missing env_vis
env_list="
env_utils
env_num_libs
env_python
env_io_libs
env_langs
env_apps
env_devel
env_bench
env_s3_clients
env_astro
env_bio
env_roms
env_wrf
"

container_list="
quay.io/biocontainers/bamtools:2.5.1--hd03093a_10
quay.io/biocontainers/bbmap:38.96--h5c4e2a8_0
quay.io/biocontainers/bcftools:1.15--haf5b3da_0
quay.io/biocontainers/bedtools:2.30.0--h468198e_3
quay.io/biocontainers/blast:2.12.0--pl5262h3289130_0
quay.io/biocontainers/bowtie2:2.4.5--py36hd4290be_0
quay.io/biocontainers/bwa:0.7.17--h7132678_9
quay.io/biocontainers/bwa-mem2:2.2.1--hd03093a_2
quay.io/biocontainers/canu:2.2--ha47f30e_0
quay.io/biocontainers/clustalo:1.2.4--h87f3376_5
quay.io/biocontainers/cutadapt:3.7--py38hbff2b2d_0
quay.io/biocontainers/diamond:2.0.14--hdcc8f71_0
quay.io/biocontainers/fastqc:0.11.9--hdfd78af_1
quay.io/biocontainers/gatk4:4.2.5.0--hdfd78af_0
quay.io/biocontainers/maker:3.01.03--pl526hb8757ab_0
quay.io/biocontainers/mrbayes:3.2.7--h19cf415_2
quay.io/biocontainers/mummer:3.23--pl5321h1b792b2_13
quay.io/biocontainers/sambamba:0.8.1--h41abebc_0
quay.io/biocontainers/samtools:1.15--h3843a85_0
quay.io/biocontainers/spades:3.15.4--h95f258a_0
quay.io/biocontainers/star:2.7.10a--h9ee0642_0
quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2
quay.io/biocontainers/trinity:2.13.2--ha140323_0
quay.io/biocontainers/vcftools:0.1.16--pl5321h9a82719_6
quay.io/biocontainers/velvet:1.2.10--h7132678_5
quay.io/sarahbeecroft9/alphafold:2.2.3
quay.io/sarahbeecroft9/interproscan:5.56-89.0
"
container_list_mpi="
quay.io/pawsey/hpc-python:2022.03
quay.io/pawsey/hpc-python:2022.03-hdf5mpi
quay.io/pawsey/openfoam:v2012
quay.io/pawsey/openfoam:v2006
quay.io/pawsey/openfoam:v1912
quay.io/pawsey/openfoam:v1812
quay.io/pawsey/openfoam-org:10
quay.io/pawsey/openfoam-org:8
quay.io/pawsey/openfoam-org:7
"

### TYPICALLY NO EDIT NEEDED PAST THIS POIINT

# python version info (no editing needed)
python_version_major="$( echo $python_version | cut -d '.' -f 1 )"
python_version_minor="$( echo $python_version | cut -d '.' -f 2 )"
python_version_bugfix="$( echo $python_version | cut -d '.' -f 3 )"

# shpc module directories for all users (system-wide and user-specific)
shpc_allusers_modules_dir_long="modules-long"
shpc_allusers_modules_dir_short="views/modules"
# shpc module suffix for SPACK USER (system-wide)
shpc_spackuser_container_tag="-container"
# name of SHPC module: decide this once and for all
shpc_name="shpc"

# name of Singularity module (Spack has singularity and singularityce)
singularity_name="singularity"

# NOTE: the following are ALL RELATIVE to root_dir above
# root location for Pawsey custom builds
custom_root_dir="custom"
# root location for Pawsey utilities (spack, shpc, scripts)
utilities_root_dir="pawsey"
# root location for containers
containers_root_dir="containers"
# location for Pawsey custom build modules
custom_modules_dir="${custom_root_dir}/modules"
# location for Pawsey custom build software
custom_software_dir="${custom_root_dir}/software"
# location for Pawsey utility modules
utilities_modules_dir="${utilities_root_dir}/modules"
# location for Pawsey utility software
utilities_software_dir="${utilities_root_dir}/software"
# location for SHPC container modules
shpc_containers_modules_dir="${containers_root_dir}/${shpc_allusers_modules_dir_short}"
# location for SHPC container modules (long version, as installed)
shpc_containers_modules_dir_long="${containers_root_dir}/${shpc_allusers_modules_dir_long}"
# location for SHPC containers
shpc_containers_dir="${containers_root_dir}/sif"

# suffix for Pawsey custom build modules
custom_modules_suffix="custom"
# suffix for Project modules
project_modules_suffix=""   # "project-apps" # let us keep it standard vs spack
# suffix for User modules
user_modules_suffix=""   # "user-apps" # let us keep it standard vs spack

# location of SHPC utility installation
shpc_install_dir="${utilities_software_dir}/${shpc_name}"
# location of SHPC utility modulefile
shpc_module_dir="${utilities_modules_dir}/${shpc_name}"

# location of Singularity modulefile (arch/compiler free symlink)
singularity_symlink_module_dir="${utilities_modules_dir}/${singularity_name}"

# location for Spack modulefile
spack_module_dir="${utilities_modules_dir}/spack"

fi # end include guard
