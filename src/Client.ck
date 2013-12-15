/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: Client.ck
Desc: Code for the client to run to translate inter-application
MIDI into the requisite OSC messages. Can be run directly 
or (ideally) could be packaged in something double clickable.
***********************************************************************/
OscRecv orec;
OscSend osend; // client needs to receive data early on and to send throughout
MidiIn min; // pretty much the point

false => int debug;

50000 => int port;
50001 => int portIn;
"localhost" => string hostname => string selfIP;
0 => int portSet => int hostSet => int midiSet => int rcvPortSet => int selfIPSet;

// for now specify port and host on command line
// one or the other or both
// if the first character is not a digit OR if it contains full stops
// it must be IP otherwise it must be port
// this file needs to stand alone, will copy the requisite functions 
// from Util.ck for now
if ( me.args() > 0 )
{
    for ( int i; i < me.args(); i++ ) 
    {
        // is it the port or the hostname?
        
        // is it in the format AAA.BBB.CCC.DDD?
        if ( RegEx.match( "([0-9]{1,3}\\.){3}[0-9]{1,3}", me.arg(i) ) && me.arg(i).find("self=") == -1 )
        {
            setHost( me.arg(i) );
        }
        else if ( RegEx.match( "^[0-9]+$", me.arg(i) ) ) // if it is just a number
        {
            if ( portSet ) // should probably not do this twice
            {
                cherr <= "(Client) Error: trying to set port a second time, ignoring." <= IO.nl();
            }
            else
            {
                chout <= "(Client) Setting port to " <= me.arg(i).toInt() <= IO.nl();
                me.arg(i).toInt() => port;
                1 => portSet; 
            }
        }
        else
        {
            if ( me.arg(i).find("midi=") >= 0 ) // present
            {    
                if ( !midiSet )// set midi
                {
                    me.arg(i).substring(5) => string midiname;
                    if ( RegEx.match( "^[0-9]+$", midiname ) )
                    {
                        if ( !min.open( midiname.toInt() ) )
                        {
                            cherr <= "(Client) Error: failed to open MIDI port number " <= midiname.toInt() <= IO.nl(); 
                        }
                        else
                        {
                            chout <= "(Client) Opened MIDI port [" <= midiname.toInt() <= "]" <= min.name() <= IO.nl();
                            1 => midiSet;
                        }
                    }
                    else
                    {
                        trimQuotes( midiname ) => midiname;
                        if ( !min.open( midiname ) )
                        {
                            cherr <= "(Client) Error: failed to open MIDI port " <= midiname <= IO.nl();
                        }
                        else
                        {
                            chout <= "(Client) Opened MIDI port " <= min.name() <= IO.nl();
                            1 => midiSet;
                        }
                    }
                }
            }
            else if ( me.arg(i).find("in=") >= 0 )
            {
                me.arg(i).substring(3) => string inport;
                if ( RegEx.match( "^[0-9]+$", inport ) )
                {
                    // we have a number
                    if ( !rcvPortSet )
                    {
                        inport.toInt() => portIn;
                        chout <= "(Client) Receive port set to " <= portIn <= IO.nl();
                        1 => rcvPortSet;
                    }
                    else
                    {
                        cherr <= "(Client) Attempting to set receive port twice from the same arguments." <= IO.nl();
                    }
                }
                else
                {
                    cherr <= "(Client) Error: receive port not specified as a number? Got: " <= inport <= IO.nl();
                }
            }
            else if ( me.arg(i).find("self=") >= 0 ) // set our own ip
            {
                if ( !selfIPSet )
                {
                    me.arg(i).substring(5) => string self;
                    // is it numbers or words?
                    trimQuotes( self ) => selfIP;
                    chout <= "(Client) Setting self IP to " <= selfIP <= IO.nl();
                    1 => selfIPSet;
                }
                else 
                {
                    cherr <= "(Client) Error: attempting to set self IP more than once in the same arguments" <= IO.nl();
                }
            }
            else
            {
                setHost( trimQuotes( me.arg(i) ) );
            }
        }
    }
}

// osc receive
if ( !rcvPortSet)
    chout <= "(Client) Note: receive port not set, defaulting to " <= portIn <= IO.nl();
portIn => orec.port;
chout <= "(Client) OSC listening on port " <= portIn <= IO.nl();
orec.listen();

// osc send
osend.setHost( hostname, port );

if ( !midiSet )
{
    chout <= "(Client) Midi not specified, attempting to open port 0" <= IO.nl();
    if ( !min.open(0) )
    {
        cherr <= "(Client) Error: could not open MIDI port 0" <= IO.nl();
        me.exit();
    }
}

// set up listeners for messages back from server
// messages from server are
// /instruments/add, s
//           — add an instrument with the given name and default messages

string instruments[0]; // the names of the instruments
MessagePair messages[0][0];// and their messages, assumed to be ii or it would be a challenge to transform from midi


// start listening for non-default messages available
spork~instrumentMethodListener();
// start listening for replies before we actually tell the server we exist, jic
spork~instrumentAddListener();

// waaait
500::ms => now;
// now tell the server we exist
osend.startMsg( "/system/addme", "si" );
osend.addString( selfIP );
osend.addInt( portIn );
chout <= "(Client) Attempted to initiate contact with Server" <= IO.nl();
// message should be kicked, everything is good to go except the midi listening

// drop into main loop (ie this shred is the MIDI listener)
chout <= "(Client) Entering main loop. " <= IO.nl();
MidiMsg msg;
// main loop
while ( true )
{
    min => now;
    while ( min.recv( msg ) )
    {
        // get channel
        msg.data1 & 0x0f => int chan;
        // get type
        msg.data1 & 0xf0 => int msgtype;
        // get name of instrument
        if ( chan >= instruments.cap() )
        {
            if (debug) 
                cherr <= "(Client) Received MIDI on channel " <= chan+1 <= " without a registered instrument." <= IO.nl();
            break;
        }
        instruments[chan] => string name;
        // find the appropriate message
        for ( int i; i < messages[name].cap(); i++ )
        {
            if ( messages[name][i].statusbyte == msgtype )
            {
                if (debug)
                    chout <= "(Client) [" <= name <= "] " <= messages[name][i].addresspattern <= IO.nl();
                osend.startMsg( messages[name][i].addresspattern, "ii" );
                osend.addInt( msg.data2 );
                osend.addInt( msg.data3 );
                break;
            }
        }
    }
}

// listens for messages from the server to construct the list of messages
// should terminate when the list is done, the server will send a special
// string for this
fun void instrumentAddListener()
{
    orec.event("/instruments/add,s") @=> OscEvent evt;
    
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            evt.getString() => string name;
            if ( name != "END" )
            {
                instruments << name;
                initialiseLastInstrument();
                if ( instruments.size() > 16 )
                    chout <= "(Client) More than 16 instruments present on server, I hope you weren’t trying to use MIDI for them all." <= IO.nl();
               if (debug)
                chout <= "(Client) Added instrument '" <= instruments[instruments.cap()-1] <= "' on channel: " <= instruments.size() <= IO.nl();
            }
            else
            {
                if (debug)
                    chout <= "(Client) new instrument listener received END" <= IO.nl();
                onEnd();
                me.exit();
            }
        }
    }
}

// listens for messages telling about extensions to given instruments
fun void instrumentMethodListener()
{
    orec.event("/instruments/extend,ssi") @=> OscEvent evt;
    
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            evt.getString() => string name;
            
            if ( name == "END" )
            {
                if (debug)
                    chout <= "(Client) Method listener received END" <= IO.nl();
                onEnd();
                me.exit();
            }
            
            evt.getString() => string pat;
            evt.getInt() => int status; // get desired midi message type to plug
            
            if (debug)
                chout <= "(Client) Received method for " <= name <= IO.nl();
            
            if ( pat.find( name ) != 1 ) // not preceded by /name, attempt to recover
            {
                "/" + name + pat => pat;
            }
            
            // strip typetag if it equals ii
            if ( RegEx.match( ",[ ]*ii$", pat ) )
            {
                pat.length()-1 => int newLength;
                while ( pat.charAt(newLength) != ',' ) newLength-1 => newLength;
                pat.substring(0, newLength) => pat;
            }
            
            MessagePair p;
            pat => p.addresspattern;
            if ( status != -1)
                status & 0xf0 => status;
            status => p.statusbyte;
            messages[name]<<p;
        }
    }
}

// prints the instruments when both the add and the extend listeners
// have returned
int numQuit;
fun void onEnd()
{
    if (++numQuit == 2) // both of them
    {
        500::ms => now;
        chout <= "(Client) Server signalled end, received: " <= instruments.size() <= IO.nl();
        for ( int i; i < instruments.size(); i++ )
        {
            instruments[i] => string name;
            chout <= "(Client)    " <= instruments[i] <= " on channel " <= i+1 <= IO.nl();
            for ( int j; j < messages[instruments[i]].size(); j++ )
            {
                if ( messages[name][j].statusbyte >= 128 )
                    chout <= "(Client)        " <= messages[name][j].statusbyte+i <= " becomes " <= messages[name][j].addresspattern <= IO.nl();
                else
                    chout <= "(Client)        " <= messages[name][j].addresspattern <= " available." <= IO.nl();
            }
        }
    }
}

// initialises the last instrument in the list
// assigns a midi channel (actually already done just by putting it in the array)
// adds the default OSC send data to that table
fun void initialiseLastInstrument()
{
    instruments.size() -1 => int inst;
    if (debug)
        chout <= "(Client) Adding standard messages to " <= instruments[inst] <= IO.nl();
    // set up the defaults
    getDefaultMessages(instruments[inst]) @=> MessagePair m[];
    // sync, no explicit locks, have no idea how granular things actually are
    if ( messages[instruments[inst]] == null )
        m @=> messages[instruments[inst]];
    else
        for ( int i; i < m.cap(); i++ )
            messages[instruments[inst]]<<m[i];
    // i think that is all
}

// returns address patterns for the default messages (note and control) in a numerically indexed array
fun MessagePair[] getDefaultMessages( string name )
{
    MessagePair patterns[2];
    "/" + name + "/note" => patterns[0].addresspattern;
    144 => patterns[0].statusbyte;
    "/" + name + "/control" => patterns[1].addresspattern;
    176 => patterns[1].statusbyte;
    return patterns;
}

fun void setHost( string newhost )
{   
    if ( hostSet )
    {
        cherr <= "(Client) Error: setting host a second time, ignoring." <= IO.nl();
    }
    else
    {
        chout <= "(Client) Setting host to " <= newhost <= IO.nl();
        newhost => hostname;
        1 => hostSet;
    }
}

/** Copied from Util.ck */
fun string trimQuotes( string in )
{
    // check if the back is quoted
    
    (in.charAt(in.length()-1) == '"') => int back; // hackery
    (in.charAt(0) == '"') => int front;
    return in.substring(front, in.length()-(front+back));
    
}

// defines a translation between a midi message and an osc message
private class MessagePair
{
    string addresspattern;
    int statusbyte;
}