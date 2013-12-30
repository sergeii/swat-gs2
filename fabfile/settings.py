# -*- coding: utf-8 -*-
import os

from unipath import Path
from fabric.api import env


env.kits = {
    'swat4': {
        'mod': 'Mod',
        'content': 'Content',
        'server': 'Swat4DedicatedServer.exe',
        'ini': 'Swat4DedicatedServer.ini',
    },
    'swat4exp': {
        'mod': 'ModX',
        'content': 'ContentExpansion',
        'server': 'Swat4XDedicatedServer.exe',
        'ini': 'Swat4XDedicatedServer.ini',
    },
}

env.roledefs = {
    'ucc': ['vm-ubuntu-swat'],
    'run': ['vm-ubuntu-swat'],
}

env.paths = {
    'here': Path(os.path.dirname(__file__)).parent,
}
env.paths['dist'] = env.paths['here'].child('dist')
env.paths['bin'] = env.paths['here'].child('bin')
env.paths['deps'] = env.paths['here'].child('deps')

env.ucc = {
    'base': Path('/home/sergei/swat4ucc/'),
    'revision': 'fff1f8d',
    'compiler': None,
}

env.run = {
    'base': Path('/home/sergei/swat4server/'),
    'revision': 'b466151',
    'settings': {
        '+[Engine.GameEngine]': (
            'ServerActors=GS2.Listener',
        ),
        '[GS2.Listener]': (
            'Enabled=True',
        ),
    }
}

env.dist = {
    'name': 'GS2',
    'version': '1.1.0-beta',
    'extra': (
        env.paths['here'].child('LICENSE'),
        env.paths['here'].child('README.html'),
        env.paths['here'].child('CHANGES.html'),
    )
}