"""Check native Python/ReFrame modules in exclusive, single-node Slurm jobs."""

import os
import re
import shlex

import reframe as rfm
import reframe.utility.sanity as sn


@rfm.simple_test
class standalone_module_check(rfm.RunOnlyRegressionTest):
    module = parameter(['python', 'reframe'])

    def __init__(self):
        self.descr = f'Load the native {self.module} module and report its version'
        self.valid_systems = ['ella:compute']
        self.valid_prog_environs = ['gcc']
        self.num_tasks = self.num_tasks_per_node = self.num_cpus_per_task = 1
        self.time_limit = '5m'
        self.tags = {'standalone', 'software_stack'}
        prefix = shlex.quote(os.environ['INSTALL_PREFIX'])
        date = os.environ['DATE_TAG']
        version = os.environ[f'{self.module}_version']
        gcc = os.environ['gcc_version']
        self.prerun_cmds = [
            'module purge', 'module load pawsey',
            f'module use {prefix}/staff_modulefiles',
            f'module load pawseyenv/{date} gcc/{gcc} {self.module}/{version} || exit 1',
        ]
        self.executable = self.module
        self.executable_opts = ['--version']
        self.expected_version = version

    @run_after('setup')
    def configure_ella_step(self):
        # Use Ella's available Slurm plugin instead of its pmix default.
        self.job.launcher.options += ['--mpi=pmi2']

    @sanity_function
    def assert_version(self):
        return sn.assert_found(re.escape(self.expected_version), self.stdout)
