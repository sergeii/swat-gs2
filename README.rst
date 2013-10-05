swat-gs2
%%%%%%%%

:Version:           1.0
:Home page:         https://github.com/sergeii/swat-gs2/
:Author:            Sergei Khoroshilov <kh.sergei@gmail.com>
:License:           BSD 3-Clause (http://opensource.org/licenses/BSD-3-Clause)
:Based on:          A code snippet by "TR1GG3R" (http://pastebin.com/UiYCKXQp)

Description
===========
This package is a replacement to the original SWAT4 GameSpy(v2) query listener library
that has gone obsolete due to GameSpy SWAT4 support shutdown.

Installation
============

1. Download the compiled binaries or compile the ``GS2`` package yourself.

2. Copy contents of a package corresponding to the game version of your server
   (either Vanilla or TSS) into the server's ``System`` directory.

3. Open ``Swat4DedicatedServer.ini`` ``(Swat4XDedicatedServer.ini)``.
4. Navigate to the ``[Engine.GameEngine]`` section.
5. Comment out or remove completely the following line::

    ServerActors=IpDrv.MasterServerUplink

   This is ought to free the +2 port (e.g. 10482) that has been occupied
   by the original GameSpy query listener.
6. Append the following line anywhere in the section::

    ServerActors=GS2.Listener

7. Add the following section at the bottom of the ``Swat4DedicatedServer.ini``::

    [GS2.Listener]
    Enabled=True

8.  The ``Swat4DedicatedServer.ini`` contents now should look like this::

        [Engine.GameEngine]
        EnableDevTools=False
        InitialMenuClass=SwatGui.SwatMainMenu
        ...
        ;ServerActors=IpDrv.MasterServerUplink
        ServerActors=GS2.Listener
        ...

        [GS2.Listener]
        Enabled=True

9. Your server is now ready to listen to GameSpy v2 protocol queries on the +2 port (game port+2).

Properties
==========
The ``[GS2.Listener]`` section of ``Swat4DedicatedServer.ini`` supports the following properties:

.. list-table::
   :widths: 15 40 10 10
   :header-rows: 1

   * - Property
     - Descripion
     - Type
     - Default
   * - Enabled
     - Toggles the listener on and off (requires a restart).
     - Boolean
     - False
   * - Port
     - The port to listen on.

       The default policy is to mimic behaviour of the original library that
       binds the query port to the value of the game port incremented by 2.
       You are free to set up a fixed value for the port to listen on.
     - Integer (*1-65535*)
     - game port+2
   * - Efficient
     - Instruct the listener to follow the efficiency policy.

       The current efficiency policy enforces player ping values
       to be faked and reduced to a one byte digit.
     - Boolean
     - False

Known issues
============
+ The listener would not respond with a full list of players
  if it's response payload size exceeded 255 bytes.

  The reason behind this is the API restrictions.
  Unlike the original library that has been written in C++,
  this one implements the UnrealEngine2 API.
  Unfortunately the latter enforces some restrictions such as response size of a binary payload.

  To deal with this restriction the listener cuts as many players as it needs
  to fit into the limit and respond to a query.

  Reducing number of players that are included in a response is a intentional
  behaviour that is considered a "feature" rather than a bug!
  While the other implementations of the custom GameSpy(v2) query listener libraries
  implementing the UnrealEngine2 API (including the one that this work has derived from)
  would ignore a query in a such a case, this implementation would simply adjust it's response.
  Voilà!

Acknowledgements
================
This project is a fork of the code snippet found elsewhere on the internet: (http://pastebin.com/UiYCKXQp).
The original author is claimed to be "TR1GG3R" (http://www.houseofpain.tk/)
