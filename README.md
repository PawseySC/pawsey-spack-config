# pawsey-spack-config

Configuration files for Spack at Pawsey.



## Setonix setup

The `setonix/` directory contains the following:
* `configs_all_users/`: configuration files for Setonix that is valid for all users 
* `config_spackuser_pawseystaff/`: configuration files for system-wide installs
* `environments/`: environments for deployment on Setonix
* `repo_setonix/`: custom package recipes for Setonix
* `templates_setonix/`: custom templates 
* `

The software stack is installed under `/sofware/setonix/YYYY.MM/` with the following sub-directories:
* `software`: software installations
* `modules`: modulefules
* `spack`: Spack installation
* `pawsey-spack-config`: this repo, including `setonix/repo_setonix` for customised package recipes



## Other setups

* `examples/`: deployment examples and tests
* `examples/joey_sprint/`: team sprints on Joey
