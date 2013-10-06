# -*- coding: utf-8 -*-
import os
import glob
from contextlib import contextmanager

from unipath import Path
from fabric.api import *


env.here = Path(os.path.dirname(__file__))
env.version = 'v1.0'
env.bin_path = env.here.child('bin')
env.dist_glob = env.bin_path.child('*', '*.u')
env.dist_path = env.here.child('dist')
env.dist_extra = (
    env.here.child('LICENSE'),
    env.here.child('README.html'),
    env.here.child('CHANGES.html')
)

@task
def mkrelease():
    mkreadme()
    version=prompt('Release version:', default=env.version).strip()
    with settings(version=version):
        mkdist()

@task
def mkreadme():
    with here():
        local('rst2html {} {}'.format('CHANGES.rst', 'CHANGES.html'))
        local('rst2html {} {}'.format('README.rst', 'README.html'))

@task
def mkdist():
    with quiet():
        if not local('ls %s' % env.dist_path):
            local('mkdir -p %s' % env.dist_path)
    for path in glob.glob(env.dist_glob):
        path = Path(path)
        relpath = Path(os.path.relpath(path, start=env.bin_path))
        if relpath:
            # construct package name
            filename = [env.here.name, env.version]
            for component in relpath.components()[1:-1]:
                filename.append(component.lower())
            filename.extend(['tar', 'gz'])
            # zip the following files
            contents = (path,) + env.dist_extra
            with lcd(env.dist_path):
                local('tar -czf {} {} '.format(
                    '.'.join(filename),
                    ' '.join(['-C {0.parent} {0.name}'.format(f) for f in contents])
                ))


@contextmanager
def here():
    with lcd(env['here']):
        yield
