# -*- coding: utf-8 -*-
import uuid
import glob
from StringIO import StringIO
from contextlib import contextmanager

from unipath import Path, DIRS
from fabric.api import *

from .settings import *

env.always_use_pty = False
env.use_ssh_config = True

_kits = env.kits.keys()

@task
@roles('ucc')
def all():
    """Deploy package source code, compile it and retrieve the compiled binaries."""
    clean()
    deploy()
    make()
    retrieve()

@task
@roles('ucc')
def make():
    """Run UCC make utility."""
    for kit in env.kits.keys():
        with system(kit):
            ucc('make --nobind')

@task
@roles('ucc')
def deploy():
    """Deploy package source code onto virtual machine."""
    with here():
        for kit, opts in env.kits.items():
            packages = []
            source_dir = env.ucc['base'].child(opts['mod'], opts['content'])
            # rm existing package directory
            with quiet():
                run('rm -rf {}'.format(source_dir.child(env.dist['name'])))
                # transfer package contents over ssh
                put(env.dist['name'], source_dir)
                # deploy dependencies
                try:
                    for dep in env.paths['deps'].child('ucc', kit).listdir(filter=DIRS):
                        put(dep, source_dir)
                        packages.append(dep.name)
                except OSError:
                    pass
            with system(kit):
                 # register package along with its dependencies
                packages.append(env.dist['name'])
                 # remove previous occurrences of the EditPackages=%Package% line
                for package in packages:
                    run(r'sed -i "s/EditPackages={0}//" {1}'.format(package, 'UCC.ini'))
                # append EditPackages=%(package) to the end of the EditPackages list 
                for package in packages[::-1]:
                    run(r'sed -i "s/EditPackages=SwatGui/\0\nEditPackages={0}/" {1}'.format(package, 'UCC.ini'))

@task
@roles('ucc')
def clean():
    """Reset the kit's git working tree to match the specified revision."""
    with cd(env.ucc['base']):
        git('reset --hard {}'.format(env.ucc['revision']))
        git('clean -fdx')

@task
@roles('ucc')
def retrieve():
    """Retrieve compiled packages."""
    package = '{}.u'.format(env.dist['name'])
    # retrieve compiled package from a mod's System directory
    for kit, opts in env.kits.items():
        remote_package = env.ucc['base'].child(opts['mod'], 'System', package)
        local_package = Path(env.paths['bin'].child(kit, package))
        with quiet():
            local('mkdir -p {}'.format(local_package.parent))
        get(remote_package, local_package)

def ucc(command):
    """Run a ucc command in conjunction with the system context manager."""
    run('wine {} {}'.format(env.ucc['compiler'], command))

def git(command):
    """Run a git command."""
    run('git {}'.format(command))

@contextmanager
def system(kit):
    """Set CWD and ucc environment variables appropriate to the specified kit branch.""" 
    with cd(env.ucc['base'].child(env.kits[kit]['mod'], 'System')):
        env.ucc['compiler'] = env.ucc['base'].child(env.kits[kit]['content'], 'System', 'UCC.exe')
        yield

@task
def mkrelease():
    """Make a new package release."""
    mkreadme()
    version = prompt('Release version:', default=env.dist['version']).strip()
    with settings(version=version):
        mkdist()

@task
def mkreadme():
    """Generate README and CHANGES html files from their respective rst sources."""
    with here():
        local('rst2html {} {}'.format('CHANGES.rst', 'CHANGES.html'))
        local('rst2html {} {}'.format('README.rst', 'README.html'))

@task
def mkdist():
    """Assemble a release dist package."""
    # create the dist directory 
    with quiet():
        if not local('ls %s' % env.dist['packaged']):
            local('mkdir -p %s' % env.dist['packaged'])
    # find compiled packages
    for (dirpath, dirnames, filenames) in os.walk(env.paths['bin']):
        for path in glob.glob(Path(dirpath).child('*.u')):
            path = Path(path)
            # get path of a compile package relative to the directory
            relpath = Path(os.path.relpath(path, start=env.paths['bin']))
            if relpath:
                # first two components of the assembled dist package name
                # are the original swat package name and its version..
                filename = [env.paths['here'].name, env.dist['version']]
                for component in relpath.components()[1:-1]:
                    # also include names of directories the components
                    # of the relative path
                    filename.append(component.lower())
                filename.extend(['tar', 'gz'])
                # tar the following files
                contents = (path,) + env.dist['extra']
                with lcd(env.dist['packaged']):
                    local('tar -czf {} {} '.format(
                        '.'.join(filename),
                        ' '.join(['-C {0.parent} {0.name}'.format(f) for f in contents])
                    ))

@task
@roles('run')
def setup():
    """Set up a demo server environment."""
    with cd(env.run['base']):
        git('reset --hard {}'.format(env.run['revision']))
        git('clean -fdx')

@task
@roles('run')
def kill(kits=_kits):
    """Stop all Swat4DedicatedServer(X).exe processes."""
    with quiet():
        for kit in kits:
            run('killall {}'.format(env.kits[kit]['server']))

@task
@roles('run')
def install(kits=_kits):
    """Install the compiled package on a demo server."""
    with quiet():
        # configure a separate server for every listed kit
        for kit in kits:
            with cd(env.run['base'].child(env.kits[kit]['content'], 'System')):
                contents = {}
                section = None
                # copy the compiled package
                put(env.paths['bin'].child(kit, '{}.u'.format(env.dist['name'])), '.')
                # get the dedi ini file
                tmp_ini = Path('/tmp').child(str(uuid.uuid4()))
                get(env.kits[kit]['ini'], tmp_ini)
                # now edit the ini file locally
                with open(tmp_ini, 'rU') as fp:
                    for line in fp:
                        line = line.strip()
                        # a section
                        if line.startswith('['):
                            try:
                                extra_opts = env.run['settings']['+%s' % section]
                            except KeyError:
                                pass
                            else:
                                # append opts to the end of the previous section
                                for extra_opt in extra_opts:
                                    if extra_opt not in contents[section]:
                                        contents[section].append(extra_opt)
                            # remember the new section
                            section = line
                            continue
                        # an ordinary line
                        if section not in env.run['settings']:
                            contents.setdefault(section, []).append(line)
                # now append extra sections
                for extra_section, extra_opts in env.run['settings'].items():
                    if not extra_section.startswith('+'):
                        for extra_opt in extra_opts:
                            contents.setdefault(extra_section, []).append(extra_opt)
                output = StringIO()
                for section, options in contents.items():
                    # prepend section title with a newline
                    output.write('{1}{0}{1}'.format(section, '\n'))
                    for opt in options:
                        # filter empty strings out
                        if opt:
                            output.write('{0}{1}'.format(opt, '\n'))
                # transfer modified contents back
                put(output, env.kits[kit]['ini'])
                output.close()

@task
@roles('run')
def launch(kits=_kits):
    """Run a swat demo server."""
    # configure a separate server for every listed kit
    for kit in kits:
        puts('Starting {}'.format(env.kits[kit]['server']))
        with cd(env.run['base'].child(env.kits[kit]['content'], 'System')):
            run('wine {}'.format(env.kits[kit]['server']))
    try:
        while True:
            pass
    except:
        kill(kits)

@contextmanager
def here():
    with lcd(env.paths['here']):
        yield