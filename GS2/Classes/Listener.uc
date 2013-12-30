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
var protected array<byte> Data;

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

public function BeginPlay()
{
    local int BoundPort;
    //Avoid double init
    if (Level.Game == None || SwatGameInfo(Level.Game) == None)
    {
        return;
    }
    self.LinkMode = MODE_Binary;
    //Listen on a +2 port if none specified
    if (self.Port == 0)
    {
        self.Port = SwatGameInfo(Level.Game).GetServerPort() + 2;
    }
    //Bind the port (use next available if possible)
    BoundPort = self.BindPort(self.Port, true);
    //Port has been successfully bound - move on
    if (BoundPort > 0)
    {
        log(self $ ": listening on " $ BoundPort);
        //Update the Swat4DedicatedServer(X).ini config file
        if (self.Port != BoundPort)
        {
            self.Port = BoundPort;
            self.SaveConfig("", "", false, true);
            self.FlushConfig();
        }
        return;
    }
    //Nah
    log(self $ ": could not bind a port (" $ self.Port $ ")");
    self.Destroy();
}

event ReceivedBinary(IpAddr Addr, int Count, byte B[255])
{
    // See if another request is being served right now
    if (self.bLocked)
    {
        return;
    }
    //Empty data sent with the previous response
    self.ResetData();
    //Check if this is a valid GameSpy V2 query request
    if (self.IsGameSpy2Query(B))
    {
        self.bLocked = true;
        self.PrepareHeader(B);
        //Server information and rules
        if (B[23] == 0xFF)
        {
            self.PrepareMain();
        }
        //Player information
        if (B[24] == 0xFF)
        {
            self.PreparePlayers();
        }
        //Respond
        self.SendData(Addr);
        // Unlock the listener
        self.bLocked = false;
    }
}

protected function SendData(IpAddr Addr)
{
    local int i;
    local byte Packet[255];
    //Only send data that could be fit into a 255 byte single packet
    if (self.Data.Length > 0 && self.Data.Length <= 255)
    {
        for (i = 0; i < self.Data.Length; i++)
        {
            Packet[i] = self.Data[i];
        }
        self.SendBinary(Addr, self.Data.Length, Packet);
    }
    else
    {
        log(self $ ": unable to send data of " $ self.Data.Length $ " bytes");
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

protected function AppendData(array<byte> byteArray)
{
    local int i;

    for (i = 0; i < byteArray.Length; i++)
    {
        self.Data[self.Data.Length] = byteArray[i];
    }
}

protected function ResetData()
{
    self.Data.Remove(0, self.Data.Length);
}

protected function PrepareHeader(byte B[255])
{
    self.AppendData(FetchHeader(B));
}

protected function PrepareMain()
{
    self.AppendData(FetchMain());
}

protected function PreparePlayers()
{
    local int n;
    //Send a 255 byte max response at all cost, sacrificing players if needed
    //Try it with the actual player count first
    n = SwatGameInfo(Level.Game).NumberOfPlayersForServerBrowser();
    //Attempt to get rid of some players in order to fit into the 255 byte packet size limit
    while ((Data.Length + self.GetArrayLength(FetchPlayerHeader(n)) + self.GetArrayLength(FetchPlayerList(n))) > 255)
    {
        //Prevent infinite loop
        if (n-- == 0)
        {
            //Even with zero players we still can't be sure if we fit into the limit
            //We would know about that in SendData() if we didn't
            break;
        }
    }
    //Append header
    self.PreparePlayerHeader(n);
    //Append player list
    self.PreparePlayerList(n);
}

protected function PreparePlayerHeader(int NumPlayers)
{
    self.AppendData(FetchPlayerHeader(NumPlayers));
}

protected function PreparePlayerList(int NumPlayers)
{
    self.AppendData(FetchPlayerList(NumPlayers));
}

protected function array<byte> FetchHeader(byte B[255])
{
    local array<byte> byteHeader;
    local int i;
    //Delimiter
    self.AppendByteToArray(FetchNull(), byteHeader);
    //Unique identifier (4 bytes)
    for (i = 19; i < 23; i++)
    {
        self.AppendByteToArray(B[i], byteHeader);
    }
    return byteHeader;
}

protected function array<byte> FetchMain()
{
    local int i;
    local array<string> Keys, Values;
    local array<byte> byteMain;

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
        //Key
        self.AppendStringToArray(Keys[i], byteMain);
        //Value
        self.AppendStringToArray(Values[i], byteMain);
    }

    //Empty key/value (end of key/value pairs)
    self.AppendByteToArray(self.FetchNull(), byteMain);
    self.AppendByteToArray(self.FetchNull(), byteMain);

    return byteMain;
}

protected function array<byte> FetchPlayerHeader(int NumPlayers)
{
    local int i;
    local array<string> Keys;
    local array<byte> byteHeader;

    Keys[0] = "player_";
    Keys[1] = "score_";
    Keys[2] = "ping_";
    //Empty string (end of player info description)
    self.AppendByteToArray(FetchNull(), byteHeader);
    //Player count
    self.AppendByteToArray(NumPlayers, byteHeader);
    //Player keys
    for (i = 0; i < Keys.Length; i++)
    {
        self.AppendStringToArray(Keys[i], byteHeader);
    }
    //Delimiter
    self.AppendByteToArray(FetchNull(), byteHeader);

    return byteHeader;
}

protected function array<byte> FetchPlayerList(int NumPlayers)
{
    local int i, n;
    local array<string> Values;
    local array<byte> bytePlayers;
    local PlayerController PC;

    foreach DynamicActors(class'PlayerController', PC)
    {
        if (PC != None)
        {
            Values[0] = PC.PlayerReplicationInfo.PlayerName;
            Values[1] = string(SwatPlayerReplicationInfo(PC.PlayerReplicationInfo).netScoreInfo.GetScore());
            Values[2] = string(GetPlayerPing(PC));
            //Append name, score and ping
            for (i = 0; i < Values.Length; i++)
            {
                self.AppendStringToArray(Values[i], bytePlayers);
            }
            //Player limit reached
            if (++n >= NumPlayers)
            {
                break;
            }
        }
    }

    return bytePlayers;
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
    local int i;
    local array<byte> byteString;

    for (i = 0; i < Len(Str); i++)
    {
        self.AppendByteToArray(Asc(Mid(Str, i, 1)), byteString);
    }

    //Delimiter
    self.AppendByteToArray(FetchNull(), byteString);

    return byteString;
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

protected function AppendStringToArray(coerce string Str, out array<byte> byteArray)
{
    local int i;
    local array<byte> byteString;

    byteString = FetchString(Str);

    for (i = 0; i < byteString.Length; i++)
    {
        self.AppendByteToArray(byteString[i], byteArray);
    }
}

protected function AppendByteToArray(byte B, out array<byte> byteArray)
{
    byteArray[byteArray.Length] = B;
}

protected function int GetArrayLength(array<byte> byteArray)
{
    return byteArray.Length;
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
