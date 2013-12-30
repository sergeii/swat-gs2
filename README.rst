swat-gs2
%%%%%%%%

:Version:           1.1.0-beta
:Home page:         https://github.com/sergeii/swat-gs2
:Author:            Sergei Khoroshilov <kh.sergei@gmail.com>
:License:           `BSD 3-Clause <http://opensource.org/licenses/BSD-3-Clause>`_
:Based on:          `GameSpy 2 Server Query <http://pastebin.com/UiYCKXQp>`_

Description
===========
This package provides an ability for a SWAT 4 server to respond to `Gamespy Protocol 2 <http://int64.org/docs/gamestat-protocols/gamespy2.html>`_ queries.

Installation
============

1. `Download <https://github.com/sergeii/swat-gs2/releases>`_ compiled binaries or compile the ``GS2`` package yourself.

   Every release is accompanied by two tar files, each containing a compiled package for a specific game version::

      swat-gs2.X.Y.Z.swat4.tar.gz
      swat-gs2.X.Y.Z.swat4exp.tar.gz

   with `X.Y.Z` being the package version, followed by a game version identifier::

      swat4 - SWAT 4 1.0-1.1
      swat4exp - SWAT 4: The Stetchkov Syndicate

   Please check the `releases page <https://github.com/sergeii/swat-gs2/releases>`_ to get the latest stable package version appropriate to your server game version.

2. Copy contents of a tar archive into the server's `System` directory.

3. Open ``Swat4DedicatedServer.ini``

4. Navigate to the ``[Engine.GameEngine]`` section.

5. Comment out or remove completely the following line::

    ServerActors=IpDrv.MasterServerUplink

   This is ought to free the +2 port (e.g. 10482) that has been occupied by the native gamespy query listener.

6. Insert the following line anywhere in the section::

    ServerActors=GS2.Listener

7. Add the following section at the bottom of the file::

    [GS2.Listener]
    Enabled=True

8. The ``Swat4DedicatedServer.ini`` contents should look like this now::

    [Engine.GameEngine]
    EnableDevTools=False
    InitialMenuClass=SwatGui.SwatMainMenu
    ...
    ;ServerActors=IpDrv.MasterServerUplink
    ServerActors=GS2.Listener
    ...

    [GS2.Listener]
    Enabled=True

9. | Your server is now ready to listen to gamespy protocol queries on a +2 port (join port+2).
   | For instance, if your server's join port number was set with the default value (i.e. 10480), the query listen port would be 10482.

Properties
==========
The ``[GS2.Listener]`` section of ``Swat4DedicatedServer.ini`` accepts the following properties:

.. list-table::
   :widths: 15 40 10 10
   :header-rows: 1

   * - Property
     - Descripion
     - Options
     - Default
   * - Enabled
     - Toggles listener on and off (requires a restart).
     - True/False
     - False
   * - Port
     - Port number to listen on.

       | By default, listener attempts to mimic behaviour of the native gamespy query listener that binds a port number equal to the join port number incremented by two.
       | If you are willing to avoid this behaviour, please set an explicit port number.
     - 1-65535
     - Join Port+2
   * - Efficient
     - | Instruct listener to follow the efficiency policy.
       | Please read more about this policy in the corresponding section below.
     - True/False
     - False

Efficiency policy
=================
Listener would not respond to a query with full list of players if it's response payload size exceeded 255 bytes.

The reason behind this is API restrictions. Unlike the native query listener that has been written in C++, listener form this package utilizes UnrealEngine2 API. Unfortunately the latter enforces some restrictions such as size of a udp response binary payload. In order to deal with such as a restriction, a response that would not initially fit into the limit, would be trimmed down removing as many players from the final output as it would need to.

A number of measures described as the *Efficiency policy* has been implemented to minimize response information loss:

* Player ping is replaced with a random one digit value.
* Strings that may pottentially contain colour and other text-decoration codes are processed in order to strip those codes off.

By default, this behaviour is disabled.

Acknowledgements
================
This project is a fork of a code snippet found `elsewhere on the internet <http://pastebin.com/UiYCKXQp>`_ written by `TR1GG3R <http://www.houseofpain.tk/>`_.