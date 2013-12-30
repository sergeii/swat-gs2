class Listener extends IPDrv.UdpLink;

 /**
 * Copyright (c) 2013, Sergei Khoroshilov
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * 
 *     1. Redistributions of source code must retain the above copyright notice,
 *        this list of conditions and the following disclaimer.
 * 
 *     2. Redistributions in binary form must reproduce the above copyright notice,
 *        this list of conditions and the following disclaimer in the documentation
 *        and/or other materials provided with the distribution.
 * 
 *     3. Neither the name of the GS2 nor the names of its contributors may be used
 *        to endorse or promote products derived from this software without
 *        specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Response fragments
 * @type array<byte>
 */
var protected array<byte> Response;

/**
 * Listener lock
 * @type bool
 */
var protected bool bLocked;

/**
 * Indicate whether the mod is enabled
 * @default false
 * @type bool
 */
var config bool Enabled;

/**
 * Explicit port number value
 * @default Join Port + 2
 * @type int
 */
var config int Port;

/**
 * Indicate whether the efficiency policy is on
 * @default false
 * @type bool
 */
var config bool Efficient;

/**
 * Check whether the mod is enabled
 * 
 * @return  void
 */
public function PreBeginPlay()
{
    Super.PreBeginPlay();

    if (!self.Enabled)
    {
        log(self $ " is disabled");
        self.Destroy();
    }
}

/**
 * Initialize listener:
 * - Check the environment (i.e. avoid being initialized on the Entry level startup)
 * - Pick a UDP port to listen on
 * - Attempt to listen on the port
 * 
 * @return  void
 */
public function BeginPlay()
{
    Super.BeginPlay();

    if (Level.Game != None && SwatGameInfo(Level.Game) != None)
    {
        self.LinkMode = MODE_Binary;
        // Listen on a +2 port if none specified
        if (self.Port == 0)
        {
            self.Port = SwatGameInfo(Level.Game).GetServerPort() + 2;
        }
        // Port has been successfully bound - move on
        if (self.BindPort(self.Port, false) > 0)
        {
            log(self $ " is listening on " $ self.Port);
            return;
        }
        else
        {
            log(self $ " could not bind port (" $ self.Port $ ")");
        }
    }
    // Destroy the instance if none of the conditions above haven't been met
    self.Destroy();
}

/**
 * Respond to a query whenever a valid gamespy v2 request is received
 * 
 * @param   struct'IpAddr' Addr
 *          Source address
 * @param   Count
 *          Number of bytes received
 * @param   byte[255] Query
 *          Received data
 * @return  void
 */
event ReceivedBinary(IpAddr Addr, int Count, byte Query[255])
{
    // See if another request is being served right now
    if (self.bLocked)
    {
        return;
    }
    // Check if this is a valid GameSpy V2 query
    if (self.IsGameSpy2Query(Query))
    {
        self.bLocked = true;
        // Set header
        self.StartResponse(Query);
        // Server details
        if (Query[23] == 0xFF)
        {
            self.AddInfo();
        }
        // Player details
        if (Query[24] == 0xFF)
        {
            self.AddPlayers();
        }
        self.SendResponse(Addr);
        // Unlock the listener
        self.bLocked = false;
        // Cleanup
        self.EmptyResponse();
    }
}

/**
 * Attempt to send data that has been populated prior to this method call
 * 
 * @param   struct'IPAddr' Addr
 *          Destination address
 * @return  void
 */
protected function SendResponse(IpAddr Addr)
{
    local int i;
    local byte Packet[255];
    // Only send response that could fit into a 255 byte packet
    if (self.Response.Length > 0 && self.Response.Length <= 255)
    {
        for (i = 0; i < self.Response.Length; i++)
        {
            Packet[i] = self.Response[i];
        }
        self.SendBinary(Addr, self.Response.Length, Packet);
    }
    else
    {
        log(self $ " is unable to send data of " $ self.Response.Length $ " bytes");
    }
}

/**
 * Tell whether the given byte array contains valid gamespy v2 specific tokens
 * 
 * @param   byte[255] Query
 * @return  bool
 */
protected function bool IsGameSpy2Query(byte Query[255])
{
    if (Query[16] == 0xFE && Query[17] == 0xFD && Query[18] == 0x00)
    {
        return true;
    }
    return false;
}

/**
 * Populate the response byte sequence with a response header
 * 
 * @param   byte[255] Query
 *          Original request query
 * @return  void
 */
protected function StartResponse(byte Query[255])
{
    self.ExtendResponse(self.FetchResponseHeader(Query));
}

/**
 * Populate the response byte sequence with server details
 * 
 * @return  void
 */
protected function AddInfo()
{
    self.ExtendResponse(self.FetchInfo());
}

/**
 * Attempt to add details of as many players as possible,
 * considering the response size limit of 255 bytes
 * 
 * @return  void
 */
protected function AddPlayers()
{
    local int n;
    // Send a 255 byte max response at all cost, sacrificing players if needed
    n = SwatGameInfo(Level.Game).NumberOfPlayersForServerBrowser();
    // Attempt to get rid of some players in order to fit into the 255 byte limit
    while (self.Response.Length + self.GetArrayLength(self.FetchPlayers(n)) > 255)
    {
        if (n-- == 0)
        {
            // Even with zero players we still can't be sure if we fit into the limit
            // We would know about that in SendResponse() if we didn't
            break;
        }
    }
    self.ExtendResponse(self.FetchPlayers(n));
}

/**
 * Return a byte sequence populated with a query response header 
 * 
 * @param   byte[255] Query
 *          Original request query
 * @return  array<byte>
 */
protected function array<byte> FetchResponseHeader(byte Query[255])
{
    local array<byte> Bytes;
    local int i;
    // Delimiter
    self.AppendToBytes(self.FetchNull(), Bytes);
    // Unique identifier
    for (i = 19; i < 23; i++)
    {
        self.AppendToBytes(Query[i], Bytes);
    }
    return Bytes;
}

/**
 * Return a byte sequence populated 
 * with a server information query response block
 * 
 * @return  array<byte>
 */
protected function array<byte> FetchInfo()
{
    local int i;
    local array<string> Keys, Values;
    local array<byte> Bytes;

    Keys[0] = "hostname";
    Keys[1] = "numplayers";
    Keys[2] = "maxplayers";
    Keys[3] = "gametype";
    Keys[4] = "gamevariant";
    Keys[5] = "mapname";
    Keys[6] = "hostport";
    Keys[7] = "password";
    Keys[8] = "gamever";

    Values[0] = self.GetDecoratedString(ServerSettings(Level.CurrentServerSettings).ServerName);
    Values[1] = string(SwatGameInfo(Level.Game).NumberOfPlayersForServerBrowser());
    Values[2] = string(ServerSettings(Level.CurrentServerSettings).MaxPlayers);
    Values[3] = SwatGameInfo(Level.Game).GetGameModeName();
    Values[4] = Level.ModName;
    Values[5] = Level.Title;
    Values[6] = string(SwatGameInfo(Level.Game).GetServerPort());
    Values[7] = string(Level.Game.GameIsPasswordProtected());
    Values[8] = Level.BuildVersion;

    for (i = 0; i < Keys.Length; i++)
    {
        self.AppendStringToBytes(Keys[i], Bytes);
        self.AppendStringToBytes(Values[i], Bytes);
    }

    //Empty key/value (end of key/value pairs)
    self.AppendToBytes(self.FetchNull(), Bytes);
    self.AppendToBytes(self.FetchNull(), Bytes);

    return Bytes;
}

/**
 * Return a byte array populated with a players query response block
 * The number of players returned is limited by the given number
 * 
 * @param   int Count
 *          Number of players to be returned
 * @return  array<byte>
 */
protected function array<byte> FetchPlayers(int Count)
{
    local int i, n;
    local array<string> Keys, Values;
    local array<byte> Bytes;
    local PlayerController PC;

    Keys[0] = "player_";
    Keys[1] = "score_";
    Keys[2] = "ping_";

    // null at the beginning of header
    self.AppendToBytes(self.FetchNull(), Bytes);
    // Player count
    self.AppendToBytes(Count, Bytes);
    // Keys
    for (i = 0; i < Keys.Length; i++)
    {
        self.AppendStringToBytes(Keys[i], Bytes);
    }
    // null at the end of header
    self.AppendToBytes(self.FetchNull(), Bytes);
    // Values
    foreach DynamicActors(class'PlayerController', PC)
    {
        Values[0] = self.GetDecoratedString(PC.PlayerReplicationInfo.PlayerName);
        Values[1] = string(SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetScore());
        Values[2] = string(self.GetPlayerPing(PC));
        // Append name, score and ping
        for (i = 0; i < Values.Length; i++)
        {
            self.AppendStringToBytes(Values[i], Bytes);
        }
        // Player limit reached
        if (++n >= Count)
        {
            break;
        }
    }

    return Bytes;
}

/**
 * Push elements of the given byte array 
 * to the end of the response byte sequence
 * 
 * @param   array<byte> Bytes
 * @return  void
 */
protected function ExtendResponse(array<byte> Bytes)
{
    self.ExtendBytes(self.Response, Bytes);
}

/**
 * Empty the response data
 * 
 * @return  void
 */
protected function EmptyResponse()
{
    self.Response.Remove(0, self.Response.Length);
}

/**
 * Convert a string into a byte array sequence
 * corresponding to its characters mapped to their respective
 * latin-1 unicode subset code points
 * 
 * @param   string Str
 * @return  array<byte>
 */
protected function array<byte> FetchString(coerce string Str)
{
    local int i, CodePoint;
    local array<byte> Bytes;

    for (i = 0; i < Len(Str); i++)
    {
        CodePoint = Asc(Mid(Str, i, 1));
        // Replace code points that dont fit into the latin-1 set
        // with a question mark
        if (CodePoint > 0xFF)
        {
            CodePoint = 0x3F;
        }
        self.AppendToBytes(CodePoint, Bytes);
    }

    // Strings are null terminated
    self.AppendToBytes(self.FetchNull(), Bytes);

    return Bytes;
}

/**
 * Return a null byte
 * 
 * @return  byte
 */
protected function byte FetchNull()
{
    return 0x00;
}

/**
 * Append a byte to the end of the given byte sequence
 * 
 * @param   byte Byte
 * @param   array<byte> Bytes (out)
 * @return  void
 */
protected function AppendToBytes(byte Byte, out array<byte> Bytes)
{
    Bytes[Bytes.Length] = Byte;
}

/**
 * Merge two byte arrays with elements of one added on top of the other
 *
 * @param   array<byte> Dest (out)
 *          Destination sequence
 * @param   array<byte> Src
 *          Source sequence
 * @return  void
 */
protected function ExtendBytes(out array<byte> Dest, array<byte> Src)
{
    local int i;

    for (i = 0; i < Src.Length; i++)
    {
        self.AppendToBytes(Src[i], Dest);
    }
}

/**
 * Convert a string into a byte sequence and append
 * elements of the latter to the given byte array
 * 
 * @param   string Str
 * @param   array<byte> Bytes (out)
 * @return  void
 */
protected function AppendStringToBytes(coerce string Str, out array<byte> Bytes)
{
    self.ExtendBytes(Bytes, self.FetchString(Str));
}

/**
 * Return value pf the given array's Length property
 * 
 * @param   array<byte> Bytes
 * @return  int
 */
protected function int GetArrayLength(array<byte> Array)
{
    return Array.Length;
}

/**
 * Decide whether to return a real ping value corresponding 
 * to the given PlayerController instance, or to fake it,
 * in order to preserve space in a query response byte array 
 * 
 * @param   class'PlayerController' PC
 * @return  int
 */
protected function int GetPlayerPing(PlayerController PC)
{
    if (!self.Efficient)
    {
        return SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).Ping;
    }
    // Note: gametracker considers a player with a ping of zero to be a bot, hence 1-9
    return RandRange(1, 9);
}

/**
 * Decide whether the given string should be returned unchanged
 * or with text codes such as [b], [u] and [c=xxxxxx] stripped off
 * 
 * @param   string Str
 *          Original string
 * @return  string
 */
protected function string GetDecoratedString(string Str)
{
    // Only strip text codes when the efficiency policy is on
    if (self.Efficient)
    {
        return self.StripTextCodes(Str);
    }
    return Str;
}

/**
 * Return a string with text decoration codes stripped off
 * 
 * @param   string Str
 *          Potentially decorated text
 * @return  string
 */
protected function string StripTextCodes(string Text)
{
    local string TextLower;
    local int j;

    // Search for the following patterns: 
    // [cC=xxxxx], [bB], [uU], [\\bB], [\uU], [\cC]
    // If one of these is found, then perform a subsitution and do another run
    while (True)
    {
        TextLower = Lower(Text);
        // Search for a "[c=""
        j = InStr(TextLower, "[c=");
        // and then the closing bracket "]"" with 6 characters between
        if (j >= 0 && Mid(TextLower, j + 9, 1) == "]")
        {
            Text = Left(Text, j) $ Mid(Text, j + 10);
        }
        else if (InStr(TextLower, "[b]") >= 0)
        {
            ReplaceText(Text, "[b]", "");
            ReplaceText(Text, "[B]", "");
        }
        else if (InStr(TextLower, "[\\b]") >= 0)
        {
            ReplaceText(Text, "[\\b]", "");
            ReplaceText(Text, "[\\B]", "");
        }
        else if (InStr(TextLower, "[u]") >= 0)
        {
            ReplaceText(Text, "[u]", "");
            ReplaceText(Text, "[U]", "");
        }
        else if (InStr(TextLower, "[\\u]") >= 0)
        {
            ReplaceText(Text, "[\\u]", "");
            ReplaceText(Text, "[\\U]", "");
        }
        else if (InStr(TextLower, "[\\c]") >= 0)
        {
            ReplaceText(Text, "[\\c]", "");
            ReplaceText(Text, "[\\C]", "");
        }
        else
        {
            break;
        }
        continue;
    }
    return Text;
}

defaultproperties
{
    Enabled=false;
    Port=0;
    Efficient=false;
}
