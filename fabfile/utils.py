# -*- coding: utf-8 -*-
import uuid
from StringIO import StringIO
from collections import OrderedDict
from contextlib import contextmanager

from fabric.contrib.files import exists
from unipath import Path

from .settings import *


class IniFile(object):

    def __init__(self, file=None):
        super(IniFile, self).__init__()
        self.sections = self.parse_ini(file)

    def append(self, section, *lines):
        for line in lines:
            self.sections.setdefault(section, []).append(line)

    def append_unique(self, section, *lines):
        # remove previous occurrences
        for line in lines:
            try: 
                self.remove(section, line)
            except ValueError:
                pass
        self.append(section, *lines)

    def replace(self, section, *lines):
        self.sections[section] = list(lines)

    def remove(self, section, *lines):
        if not lines:
            del self.sections[section]
        else:
            for line in lines:
                self.sections[section].remove(line)

    def get_contents(self):
        contents = []
        for section, lines in self.sections.items():
            if section:
                # prepend 2-n'th section with a new line
                if contents:
                    contents.append('')
                contents.append(section)
            for line in lines:
                contents.append(line)
        return '\n'.join(contents)

    @staticmethod
    def parse_ini(path):
        sections = OrderedDict()
        if not path:
            return sections
        section = None
        with open(path, 'rU') as fp:
            for line in fp:
                line = line.strip()
                # a section
                if line.startswith('['):
                    section = line
                    continue
                if line:
                    # an ordinary non-empty line
                    sections.setdefault(section, []).append(line)
        return sections

def git(command):
    """Run a git command."""
    run('git {}'.format(command))

def checkout(remote, local):
    """
    Clone a remote repository `remote` to `local` and checkout origin/master.

    If the `remote` argument contains an optional extension `#revision`,
    then the specified revision will be checked out instead.
    """
    path, revision = (remote.split('#', 1) + [None])[:2]
    if not exists(local):
        git('clone {} {}'.format(path, local))
    with cd(local):
        rev = revision if revision else 'origin/master'
        git('fetch origin')
        git('checkout --force {}'.format(rev))
        git('reset --hard {}'.format(rev))  # --mixed?
        git('clean -fdx')

def tmp():
    """Return a Path instance for a random generated /tmp file/directory child."""
    return Path('/tmp').child(str(uuid.uuid4()))

@contextmanager
def here():
    """Set CWD to the fabfile's parent directory."""
    with lcd(env.paths['here']):
        yield

@contextmanager
def edit_ini(path):
    """Yield an IniFile object for the given ini remote file path."""
    tmp_file = tmp()
    # copy the remote file to the local /tmp dir
    get(path, tmp_file)
    # get an ini file manager
    ini = IniFile(tmp_file)
    # let the invoker modify file contents
    yield ini
    
    fobj = StringIO()
    fobj.write(ini.get_contents())
    # transfer it back to the remote machine
    put(fobj, path)
    fobj.close()
