#!/bin/bash

# assuming Singularity was installed by Spack
# here, only editing some configurations

module load singularity/${singularity_version}
singularity_path="$(which singularity)"
singularity_dir="${singularity_path%/bin/singularity}"

# Cray: use RAMFS
# beyond CLE6up05, this is not needed any more
#sed -i 's/^ *memory *fs *type *=.*/memory fs type = ramfs/g' ${singularity_dir}/etc/singularity/singularity.conf

# do not allow execution of encrypted containers
sed -i 's/^ *allow *container *encrypted *=.*/allow container encrypted = no/g' ${singularity_dir}/etc/singularity/singularity.conf

# do not mount home by default at runtime
sed -i 's/^ *mount *home *=.*/mount home = no/g' ${singularity_dir}/etc/singularity/singularity.conf
