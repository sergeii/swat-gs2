# -*- coding: utf-8 -*-
import os
import glob

from fabric.api import *
from unipath import Path

from .utils import here


@task
def readme():
    """Generate README and CHANGES html files from their respective rst sources."""
    with here():
        local('rst2html {} {}'.format('CHANGES.rst', 'CHANGES.html'))
        local('rst2html {} {}'.format('README.rst', 'README.html'))

@task
def release():
    """Assemble a release dist package."""
    # create the dist directory 
    with quiet():
        local('rm -rf {}'.format(env.paths['dist']))
        local('mkdir -p {}'.format(env.paths['dist']))
        # find compiled packages
        for (dirpath, dirnames, filenames) in os.walk(env.paths['compiled']):
            files = []
            filename = []
            for path in glob.glob(Path(dirpath).child('*.u')):
                path = Path(path)
                files.append(path)
                # filename has not yet been assembled
                if not filename:
                    # get path of a compile package relative to the directory
                    relpath = Path(os.path.relpath(path, start=env.paths['compiled']))
                    if relpath:
                        # first two components of the assembled dist package name
                        # are the original swat package name and its version..
                        filename = [env.paths['here'].name, env.dist['version']]
                        for component in relpath.components()[1:-1]:
                            # also include names of directories the components
                            # of the relative path
                            filename.append(component.lower())
                        filename.extend(['tar', 'gz'])
            if not files:
                continue
            # tar the following files
            files.extend(env.dist['extra'])
            with lcd(env.paths['dist']):
                local(r'tar -czf "{}" {} '.format(
                    '.'.join(filename),
                    ' '.join(['-C "{0.parent}" "{0.name}"'.format(f) for f in files])
                ))