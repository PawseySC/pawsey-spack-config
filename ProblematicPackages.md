# Problematic packages

A list of packages whose installation was not straightforward, and the reason why.

- `petsc` needs to submit a Slurm job as part of the configuration. Any issue with Slurm impacts the installation process.



## Packages that must be externals

- libfabric


## Packages that MUST NOT be externals

- gettext
- krb5
