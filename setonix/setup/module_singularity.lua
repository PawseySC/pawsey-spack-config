-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : singularity]])
whatis([[Version : 3.8.5]])

whatis([[Short description : A container technology focused on building portable encapsulated environments to support 'Mobility of Compute'. ]])
help([[A container technology focused on building portable encapsulated environments to support 'Mobility of Compute'.]])

-- Rationale for considering a Pawsey custom module for Singularity
-- is to have better control of the variables required to have MPI working

-- TODO: review this path
setenv("SINGULARITY_HOME","/software/pawsey0001/spack-tests/setonix/2022.01/software/cray-sles15-zen2/gcc-10.3.0/singularity-3.8.5-eig5ikxq2yyrkklutfqpwq6khk2mcxah")

-- TODO: review this path
prepend_path("PATH","/software/pawsey0001/spack-tests/setonix/2022.01/software/cray-sles15-zen2/gcc-10.3.0/singularity-3.8.5-eig5ikxq2yyrkklutfqpwq6khk2mcxah/bin")
prepend_path("PATH","/usr/sbin")

-- TODO: review these
setenv("SINGULARITYENV_LD_LIBRARY_PATH","")
setenv("SINGULARITY_BINDPATH","/askapbuffer,/astro,/scratch,/software")
setenv("SINGULARITY_CACHEDIR",os.getenv("MYSOFTWARE").."/.singularity")
-- TODO: check if the 2 below are still needed (taken from Magnus)
setenv("MPICH_GNI_MALLOC_FALLBACK","1")
setenv("PMI_MMAP_SYNC_WAIT_TIME","14000")
