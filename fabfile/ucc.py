# -*- coding: utf-8 -*-
from contextlib import contextmanager

from fabric.api import *
from unipath import Path

from .settings import env
from .utils import checkout, tmp, edit_ini

@task
@roles('ucc')
def all():
    """Deploy package source code, compile it and retrieve the compiled binaries."""
    setup()
    deploy()
    make()
    retrieve()

@task
@roles('ucc')
def setup():
    """Reset the kit's git working tree to match the specified revision."""
    checkout(env.ucc['git'], env.ucc['path'])

@task
@roles('ucc')
def deploy():
    """Deploy package source code onto virtual machine."""
    with quiet():
        for kit, opts in env.kits.items():
            source_dir = env.ucc['path'].child(opts['mod'], opts['content'])
            for package, repo in env.ucc['packages']:
                # checkout package repo to a tmp directory
                local_repo = tmp()
                checkout(repo, local_repo)
                # rm existing package source directory
                run(r'rm -rf {}'.format(source_dir.child(package)))
                # deploy package source code
                run(r'cp -r {0} {1}'.format(local_repo.child(package), source_dir))
            with system(kit):
                with edit_ini('UCC.ini') as ini:
                    for package, _ in env.ucc['packages']:
                        ini.append_unique(
                            r'[Editor.EditorEngine]', 
                            r'EditPackages={0}'.format(package)
                        )

@task
@roles('ucc')
def make():
    """Run UCC make utility."""
    for kit in env.kits.keys():
        with system(kit) as path:
            ucc(path, 'make --nobind')

@task
@roles('ucc')
def retrieve():
    """Retrieve compiled packages."""
    # retrieve compiled package from a mod's System directory
    with quiet():
        local('rm -rf {}'.format(env.paths['compiled']))
        for kit, opts in env.kits.items():
            for package, _ in env.ucc['packages']:
                package = '{}.u'.format(package)
                remote_package = env.ucc['path'].child(opts['mod'], 'System', package)
                local_package = Path(env.paths['compiled'].child(kit, package))
                with quiet():
                    local('mkdir -p {}'.format(local_package.parent))
                get(remote_package, local_package)

def ucc(path, command):
    """Run a ucc command."""
    run('wine {0} {1}'.format(path, command))

@contextmanager
def system(kit):
    """Set CWD and ucc environment variables appropriate to the specified kit branch.""" 
    with cd(env.ucc['path'].child(env.kits[kit]['mod'], 'System')):
        yield env.ucc['path'].child(env.kits[kit]['content'], 'System', 'UCC.exe')