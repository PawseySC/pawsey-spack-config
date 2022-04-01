#!/bin/bash

# list of containers to be installed by shpc
container_list="
quay.io/biocontainers/bamtools:2.5.1--hd03093a_10
quay.io/biocontainers/bbmap:38.96--h5c4e2a8_0
quay.io/biocontainers/bcftools:1.15--haf5b3da_0
quay.io/biocontainers/beast2:2.6.3--hf1b8bbb_0
quay.io/biocontainers/bedtools:2.30.0--h468198e_3
quay.io/biocontainers/blast:2.12.0--pl5262h3289130_0
quay.io/biocontainers/bowtie2:2.4.5--py36hd4290be_0
quay.io/biocontainers/bwa:0.7.17--h7132678_9
quay.io/biocontainers/bwa-mem2:2.2.1--hd03093a_2
quay.io/biocontainers/canu:2.2--ha47f30e_0
quay.io/biocontainers/clustalo:1.2.4--h87f3376_5
quay.io/biocontainers/cutadapt:3.7--py38hbff2b2d_0
quay.io/biocontainers/diamond:2.0.14--hdcc8f71_0
quay.io/biocontainers/fastqc:0.11.9--0
quay.io/biocontainers/gatk4:4.2.5.0--hdfd78af_0
quay.io/biocontainers/maker:3.01.03--pl526hb8757ab_0
quay.io/biocontainers/mrbayes:3.2.7--h5465cc4_4
quay.io/biocontainers/mummer:3.23--pl5321h1b792b2_13
quay.io/biocontainers/sambamba:0.8.1--h41abebc_0
quay.io/biocontainers/samtools:1.15--h3843a85_0
quay.io/biocontainers/spades:3.15.4--h95f258a_0
quay.io/biocontainers/star:2.7.10a--h9ee0642_0
quay.io/biocontainers/trimmomatic:0.39--hdfd78af_2
quay.io/biocontainers/trinity:2.13.2--ha140323_0
quay.io/biocontainers/vcftools:0.1.16--pl5321h9a82719_6
quay.io/biocontainers/velvet:1.2.10--h7132678_5
quay.io/pawsey/hpc-python:2022.03
quay.io/pawsey/hpc-python:2022.03-hdf5mpi
"

# source setup variables
script_dir="$(dirname $0)"
. ${script_dir}/variables.sh

# load shpc module
module load ${shpc_name}/${shpc_version}

# make sure root directory exists, for container modules installation
cd ${root_dir}
mkdir -p containers

# install container modules
# will take a while (container downloads)
# if a container module has already been installed, its installation will complete quickly
for container in $container_list ; do
  shpc install $container
done

# create compact, symlinked module tree
mkdir -p containers/${shpc_spackuser_modules_dir_short}
cd containers/${shpc_spackuser_modules_dir_short}
# avoid repetitions in symlinking
container_tool_list=""
for container in $container_list ; do
  container_tool=${container%:*}
  container_tool_list+="$container_tool "
done
unique_container_tool_list="$(echo $container_tool_list | xargs -n 1 | sort | uniq | xargs)"
# populate symlinked module tree
for container_tool in $unique_container_tool_list ; do
  container_tool_short=${container_tool##*/}
  ln -s ${root_dir}/containers/${shpc_spackuser_modules_dir_long}/${container_tool} ${container_tool_short}
  if [ "$container_tool_short" == "openfoam" ] || [ "$container_tool_short" == "openfoam-org" ] ; then
    mv ${container_tool_short} ${shpc_spackuser_openfoam_add_prefix}${container_tool_short}
  fi
done
# it's the symlinked module tree that needs to go in MODULEPATH:
# `module use ${root_dir}/containers/${shpc_spackuser_modules_dir_short}`

# back to root_dir
cd ${root_dir}
