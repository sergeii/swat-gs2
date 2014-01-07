# -*- coding: utf-8 -*-
from fabric.api import env

from . import (ucc, server, dist)

env.always_use_pty = False
env.use_ssh_config = True

