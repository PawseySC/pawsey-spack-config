export top_root_dir="/software/projects/director2183/cdipietrantonio/setonixtrial"
export INSTALL_GROUP=director2183
. variables.sh

# ./setup_spack.sh ${date_tag} 
# echo "Running first python install"
# ./run_first_python_install.sh

module --ignore-cache unload pawsey_prgenv
module use ${top_root_dir}/${date_tag}/pawsey_temp
# we need the python module to be available in order to run spack
module use ${top_root_dir}/${date_tag}/modules/zen3/gcc/12.1.0/programming-languages
module --ignore-cache load pawsey_temp
module load spack/0.17.0

