#!/bin/bash -e

export top_root_dir="${MYSOFTWARE}/setonixtrial"

. variables.sh

./setup_spack.sh ${date_tag}

./run_first_python_install.sh

