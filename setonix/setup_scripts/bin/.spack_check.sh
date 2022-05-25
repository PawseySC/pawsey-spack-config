#!/bin/bash 

#basic spack checks
isspack=$(which spack 1> /tmp/found-spack 2>/dev/null; more /tmp/found-spack )
if [ -z ${isspack} ]; then 
    echo "spack not found, please update paths to include spack"
    exit
fi
timestamp=$( date +"%Y-%m-%d_%Hh%M")
baselogdir=/software/projects/${PAWSEY_PROJECT}/${USER}/spack-logs/
