#!/bin/bash -e
#
# Generate migration scripts between current software deployment and older one 
#

# assumes current environment is current date tag
CUR_DATE_TAG=$(module --redirect show spack | grep ".lua" | sed "s:/: :g" | awk '{print $3}')
CUR_SPACK_VERSION=$(module --redirect show spack | grep ".lua" | sed "s:/: :g" | awk '{print $NF}' | sed "s/.lua://g")

if [ -z "${OLD_DATE_TAG}" ]; then
    OLD_DATE_TAG="2022.11"
fi

echo "Producing migration scripts in $(pwd) directory"
echo "Scripts are spack.specs.sh and spack.install.sh for checking the specs and for installing them"
echo "Migration is for ${MYPROJECT} project and ${MYSOFTWARE} for ${OLD_DATE_TAG} software stack deployment"
 
# unload the default gcc compiler and swap to old pawsey environment to load old spack module
module unload gcc 
module swap pawseyenv pawseyenv/${OLD_DATE_TAG}
module load gcc
OLD_SPACK_VERSION=$(module --redirect show spack | grep ".lua" | sed "s:/: :g" | awk '{print $NF}' | sed "s/.lua://g")
module load spack/${OLD_SPACK_VERSION}

# look for modules within your $MYSOFTWARE installation
hashlist=($(lfs find /software/projects/pawsey0001/pelahi/setonix/modules/ -name *.lua | sed "s/.lua//g" | sed "s/-/ /g" | awk '{print $2}'))
# query spack for these user built packages to get the build information and store it so that it can be used to generate an installation with
# the new spack
echo "#!/bin/bash" > spack.specs.sh
echo "module load spack/${CUR_SPACK_VERSION}" >> spack.specs.sh
cp spack.specs.sh spack.install.sh
for h in ${hashlist[@]}
do
  spec=$(spack find -v /${h} | tail -n 1)
  echo "spack spec -Il ${spec}" >> spack.specs.sh
  echo "spack install ${spec}" >> spack.install.sh
done

# now have to scripts to run with the newer pawsey environment
module unload spack
module unload gcc
module swap pawseyenv/${OLD_DATE_TAG} pawseyenv/${CUR_DATE_TAG}
module load gcc 

# check the specs
# bash spack.specs.sh
# if you are happy install, otherwise need to iterate on the spec script and the installation script
# bash spack.install.sh
