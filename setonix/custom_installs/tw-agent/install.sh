#!/bin/bash

# requires sourcing of /software/setonix/<DATE_TAG>/pawsey-spack-config/setonix/setup_scripts/variables.sh

# from variables.sh
#  root_dir
#  utilities_software_dir
#  utilities_modules_dir

name="tw-agent"
version="0.4.3"
install_dir="${root_dir}/${utilities_software_dir}/${name}/${version}"
module_dir="${root_dir}/${utilities_modules_dir}/${name}"


# install tool
mkdir -p ${install_dir}/bin
curl -fSL \
  https://github.com/seqeralabs/tower-agent/releases/download/v${version}/tw-agent-linux-x86_64 \
  > ${install_dir}/bin/tw-agent
chmod ugo+rx ${install_dir}/bin/tw-agent

# create module
mkdir -p ${module_dir}
sed \
  -e "s;TOOL_VERSION;${version};g" \
  -e "s;TOOL_INSTALL_DIR;${install_dir};g" \
  module.lua >${module_dir}/${version}.lua

