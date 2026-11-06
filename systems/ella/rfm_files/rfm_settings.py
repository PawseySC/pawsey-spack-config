# Copyright 2016-2022 Swiss National Supercomputing Centre (CSCS/ETH Zurich)
# ReFrame Project Developers. See the top-level LICENSE file for details.
#
# SPDX-License-Identifier: BSD-3-Clause

# Each check requests one exclusive Ella node through Slurm. No account,
# partition or allocation-pack options are needed on this cluster.
site_configuration = {
    'systems': [
        {
            'name': 'ella',
            'descr': 'Ella Grace Hopper cluster',
            'hostnames': [r'ella.*'],
            'modules_system': 'lmod',
            'partitions': [
                {
                    'name': 'compute',
                    'scheduler': 'slurm',
                    'launcher': 'srun',
                    'access': ['--nodes=1', '--exclusive'],
                    'max_jobs': 1,
                    'environs': ['gcc'],
                    'resources': [
                        {'name': 'gpu', 'options': ['--gpus-per-node={num_gpus}']},
                    ],
                    'processor': {
                        'num_cpus': 72,
                        'num_cpus_per_core': 1,
                        'num_cpus_per_socket': 72,
                        'num_sockets': 1,
                    },
                },
                {
                    'name': 'shell',
                    'scheduler': 'slurm',
                    'launcher': 'local',
                    'access': ['--nodes=1', '--exclusive'],
                    'max_jobs': 1,
                    'environs': ['gcc'],
                    'processor': {
                        'num_cpus': 72,
                        'num_cpus_per_core': 1,
                        'num_cpus_per_socket': 72,
                        'num_sockets': 1,
                    },
                },
            ],
        },
    ],
    'environments': [
        {
            'name': 'gcc',
            'target_systems': ['ella'],
            # Checks establish the native module paths before loading packages.
            'modules': [],
            'cc': 'gcc',
            'cxx': 'g++',
            'ftn': 'gfortran',
        },
    ],
    'logging': [
        {
            'level': 'debug',
            'handlers_perflog': [],
            'handlers': [
                {'type': 'stream', 'name': 'stdout', 'level': 'info',
                 'format': '%(message)s'},
                {'type': 'file', 'name': 'reframe.out', 'level': 'info',
                 'format': '%(message)s', 'append': False},
                {'type': 'file', 'name': 'reframe.log', 'level': 'debug',
                 'format': '[%(asctime)s] %(levelname)s: %(check_name)s: %(message)s',
                 'append': False},
            ],
        },
    ],
}
