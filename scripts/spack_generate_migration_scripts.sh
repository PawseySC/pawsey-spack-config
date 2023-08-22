#!/bin/bash -e
#
# Generate migration scripts between current software deployment and older one 
# Argument -s just the spec script is automatically run 
# Argument -i runs both spec and install scripts
# If nothing is passed just generates them 

usage() {
  echo "Usage: $0 [ -s ] [ -i ]" 1>&2 
}
exit_abnormal() {                         # Function: Exit with error.
  usage
  exit 1
}
while getopts "si" options; do
  case "${options}" in
    s)
      SPEC="y"
      ;;
    i)
      INSTALL="y"
      SPEC="y"
      ;;
    *)                                    # If unknown (any other) option:
      exit_abnormal                       # Exit abnormally.
      ;;
  esac
done

# assumes current environment is current date tag
CUR_DATE_TAG=$(module --redirect -t -d avail pawseyenv |  tail -n 1 | cut -d/ -f2)
CUR_SPACK_VERSION=$(module --redirect -t -d avail spack | tail -n 1 | cut -d/ -f2)

if [ -z "${OLD_DATE_TAG}" ]; then
    OLD_DATE_TAG="2022.11"
fi

echo "Producing migration scripts in $(pwd) directory"
echo "Scripts are spack.specs.sh and spack.install.sh for checking the specs and for installing them"
echo "Migration is for ${PAWSEY_PROJECT} project and ${MYSOFTWARE} for ${OLD_DATE_TAG} software stack deployment"
 
# unload the default gcc compiler and swap to old pawsey environment to load old spack module
module unload gcc 
module swap pawseyenv pawseyenv/${OLD_DATE_TAG}
module load gcc
OLD_SPACK_VERSION=$(module --redirect -t -d avail spack | tail -n 1 | cut -d/ -f2)
module load spack/${OLD_SPACK_VERSION}

# look for modules within your $MYSOFTWARE installation
hashlist=($(lfs find ${MYSOFTWARE}/setonix/modules/ -name *.lua | sed "s/.lua//g" | sed "s/-/ /g" | awk '{print $NF}'))
# query spack for these user built packages to get the build information and store it so that it can be used to generate an installation with
# the new spack
echo "#!/bin/bash" > spack.specs.sh
echo "module load spack/${CUR_SPACK_VERSION}" >> spack.specs.sh
cp spack.specs.sh spack.install.sh
rm -rf spack.specs.txt
for h in ${hashlist[@]}
do
  spec=$(spack find -v /${h} | tail -n 1)
  echo "${spec}" >> spack.specs.txt
  # echo "spack spec -Il ${spec}" >> spack.specs.sh
  # echo "spack install ${spec}" >> spack.install.sh
done
echo "while read spec; do" >> spack.specs.sh
echo "while read spec; do" >> spack.install.sh
echo "  echo \"Specking \${spec}\"" >> spack.specs.sh
echo "  spack spec -IL \${spec}" >> spack.specs.sh
echo "  echo \"Installing \${spec}\"" >> spack.install.sh
echo "  spack install \${spec}" >> spack.install.sh
echo "done <spack.specs.txt" >> spack.specs.sh
echo "done <spack.specs.txt" >> spack.install.sh

echo "Have generated migration scripts and input"
echo -e "spack.specs.txt\t- File containing the packages and their build options to be concretized and installed"
echo -e "spack.specs.sh\t- Script to generate specification and see if you are satisifed. Run with 'bash spack.specs.sh'"
echo -e "spack.install.sh\t- Script to install the packages as specified. Run with 'bash spack.install.sh'"
echo "If there are issues in specs, please alter spack.specs.txt and try running the spec script" 

# if not running the spec script, can just exit 
if [ "${SPEC}" != "y" ]; then 
  exit 1
fi

# now have to scripts to run with the newer pawsey environment
echo "Running spec script ... "
module unload spack
module unload gcc
module swap pawseyenv/${OLD_DATE_TAG} pawseyenv/${CUR_DATE_TAG}
module load gcc 
bash spack.specs.sh

if [ "${INSTALL}" = "y" ]; then
  echo "Running specification script"
  bash spack.install.sh
fi
