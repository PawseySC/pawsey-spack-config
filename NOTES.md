
### NOTE for next deployment - October/November 2022

Author: Marco.

Following an update of the SHPC installation, the `MODULEPATH`s for SHPC modules needs a once-off change, both for system-wide and user-specific installations.  
As a result, the following two steps are required, in collaboration with the Platforms team:
1. update `pawsey` module, based on the newly generated `/software/setonix/2022.XX/pawsey_load_first.lua` (done with Kevin for previous deployment);
2. update user account creation process, following the updated `/software/setonix/2022.XX/spack/bin/spack_create_user_moduletree.sh` (done with William for previous deployment).
