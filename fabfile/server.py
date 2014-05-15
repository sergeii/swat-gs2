# -*- coding: utf-8 -*-
from fabric.api import *

from .settings import env
from .utils import here, checkout, edit_ini


_kits = env.kits.keys()

@task
@roles('server')
def all():
    """Set up the compiled packages on a clean server, then launch it."""
    setup()
    install()
    launch()

@task
@roles('server')
def setup():
    """Set up a SWAT 4 test server."""
    checkout(env.server['git'], env.server['path'])

@task
@roles('server')
def install(kits=_kits):
    """Install the compiled packages on a test server."""
    with quiet():
        # configure separate servers for every listed kit
        for kit in kits:
            with cd(env.server['path'].child(env.kits[kit]['content'], 'System')):
                # transfer compiled packages
                for package, _ in env.ucc['packages']:
                    put(env.paths['compiled'].child(kit, '{}.u'.format(package)), '.')
                # edit Swat4DedicatedServer.ini
                with edit_ini(env.kits[kit]['ini']) as ini:
                    for section, lines in env.server['settings'].items():
                        # append extra lines to a section
                        if section[0] == '+':
                            ini.append_unique(section[1:], *lines)
                        # set/replace section
                        else:
                            ini.replace(section, *lines)

@task
@roles('server')
def launch(kits=_kits):
    """Run a swat demo server."""
    # configure a separate server for every listed kit
    for kit in kits:
        puts('Starting {}'.format(env.kits[kit]['server']))
        with cd(env.server['path'].child(env.kits[kit]['content'], 'System')):
            run('DISPLAY=:0 screen -d -m wine {}'.format(env.kits[kit]['server']))
    if prompt('Stop the servers?', default='y').lower().startswith('y'):
        kill(kits)

@task
@roles('server')
def kill(kits=_kits):
    """Stop all Swat4DedicatedServer(X).exe processes."""
    for kit in kits:
        puts('Stopping {}'.format(env.kits[kit]['server']))
        with quiet():
            run('killall {}'.format(env.kits[kit]['server']))