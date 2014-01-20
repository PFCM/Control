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

true => int debug;
true => int canSend; // is the server calculating latencies? We'd better not send during that

0 => int numQuit;

50000 => int port;
50001 => int portIn;
"localhost" => string hostname => string selfIP;
0 => int portSet => int hostSet => int midiSet => int rcvPortSet => int selfIPSet;
"" => string testList; // the list of instruments we want to test on client startup
"" => string delayList;

string notes[0][0]; // notes about the instruments

// for now specify port and host on command line
// one or the other or both
// if the first character is not a digit OR if it contains full stops
// it must be IP otherwise it must be port
// this file needs to stand alone, will copy the requisite functions 
// from Util.ck for now
//
if ( me.args() > 0 )
{
    for ( int i; i < me.args(); i++ ) 
    {
        // this is structured poorly
        // should tidy it up
        // and everyone will be happy
        
        // is it the server's address
        if ( RegEx.match( "([0-9]{1,3}\\.){3}[0-9]{1,3}", me.arg(i) ) && me.arg(i).find("self=") == -1 )
        {
            setHost( me.arg(i) );
        }
        else if ( RegEx.match( "^(out=){0,1}[0-9]+$", me.arg(i) ) ) // if it is just a number
        {
            if ( portSet ) // should probably not do this twice
            {
                cherr <= "(Client) Error: trying to set port a second time, ignoring." <= IO.nl();
            }
            else
            {
                me.arg(i) => string outport;
                if (RegEx.match("^out=",me.arg(i)))
                {
                    if (debug)
                        chout <= "(Client) (debug) stripping out= from output port" <= IO.nl();
                    
                    outport.substring(4) => outport;
                }
                chout <= "(Client) Setting port to " <= outport.toInt() <= IO.nl();
                outport.toInt() => port;
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
            else if ( me.arg(i).find("test=") >= 0 ) // do we want to test some biz
            {
                // don't check it yet, we don't try run the test until after handshaking (at the end of onEnd())
                me.arg(i).substring(5) => testList;
                chout <= "(Client) got \"" <= testList <= "\" to test." <= IO.nl();
            }
            else if ( me.arg(i).find("delay=") >= 0 ) // do we want to try compensate for instrument latency
            {
                // like with test we just want to store this until a bit later
                me.arg(i).substring(6) => delayList;
                chout <= "(Client) got \"" <= delayList <= "\" to use for latency calibration." <= IO.nl();
            }
            else // we assume server's address as a name, note that this is not good, we need better error checking here
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
spork~instrumentNoteListener();
spork~serverCalibrateListener();

// waaait (this actually fixed a bunch of problems)
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
                cherr <= "(Client) (debug) Received MIDI on channel " <= chan+1 <= " without a registered instrument." <= IO.nl();
            break;
        }
        instruments[chan] => string name;
        // find the appropriate message
        for ( int i; i < messages[name].cap(); i++ )
        {
            if ( messages[name][i].statusbyte == msgtype )
            {
                if (debug)
                    chout <= "(Client) (debug) [" <= name <= "] " <= messages[name][i].addresspattern <= IO.nl();
                if (canSend) // only send it if the server wants us to
                {
                    osend.startMsg( messages[name][i].addresspattern, "ii" );
                    osend.addInt( msg.data2 );
                    osend.addInt( msg.data3 );
                }
                break;
            }
        }
    }
}

// listens for messages from the server indicating it is calibrating and we should not be sending anything
fun void serverCalibrateListener()
{
    orec.event("/system/calibrate/beginning") @=> OscEvent evt;
    
    while (evt => now)
    {
        while (evt.nextMsg())
        {
            // begin
            chout <= "(Client) SERVER IS CALIBRATING LATENCIES." <= IO.nl();
            spork~calibrationDoneListener();
            false => canSend;
            while (!canSend)
            {
                if ((now%2::second)/1::samp == 0)
                {
                    chout <= ". . ." <= IO.nl();
                }
                1::samp => now;
            }
        }
    }
}

// listens for the end of the calibration, setting canSend to true and returning client to normal operation.
fun void calibrationDoneListener()
{
    orec.event("/system/calibrate/end") @=> OscEvent evt;
    
    while (evt => now)
    {
        while (evt.nextMsg())
        {
            chout <= "(Client) CALIBRATION DONE." <= IO.nl();
            chout <= "(Client) See server console for details." <= IO.nl();
            true => canSend;
            me.exit();
        }
    }
}

// listens for the end of the tests, setting canSend to true and returning client to normal operation.
fun void testEndListener()
{
    orec.event("/system/test/end") @=> OscEvent evt;
    
    while (evt => now)
    {
        while (evt.nextMsg())
        {
            chout <= "(Client) TESTS DONE. Sound ok?" <= IO.nl();
            true => canSend;
            me.exit();
        }
    }
}


// listens for messages from the server to construct the list of messages
// should terminate when the list is done, the server will send a special
// string for this
fun void instrumentAddListener()
{
    orec.event("/system/instruments/add,s") @=> OscEvent evt;
    
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
                    chout <= "(Client) (debug) Added instrument '" <= instruments[instruments.cap()-1] <= "' on channel: " <= instruments.size() <= IO.nl();
            }
            else
            {
                if (debug)
                    chout <= "(Client) (debug) new instrument listener received END" <= IO.nl();
                onEnd();
                me.exit();
            }
        }
    }
}

// listens for messages telling about extensions to given instruments
fun void instrumentMethodListener()
{
    orec.event("/system/instruments/extend,ssi") @=> OscEvent evt;
    
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            evt.getString() => string name;
            
            if ( name == "END" )
            {
                if (debug)
                    chout <= "(Client) (debug) Method listener received END" <= IO.nl();
                onEnd();
                me.exit();
            }
            
            evt.getString() => string pat;
            evt.getInt() => int status; // get desired midi message type to plug
            
            if (debug)
                chout <= "(Client) (debug) Received method for " <= name <= IO.nl();
            
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

fun void instrumentNoteListener()
{
    orec.event( "/system/instruments/note, ss" ) @=> OscEvent evt;
    
    while( evt => now )
    {
        while( evt.nextMsg() )
        {
            evt.getString() => string name;
            if (name != "END")
            {
                if (notes[name]==null)
                {
                    new string[1] @=> notes[name];
                    evt.getString() => notes[name][0];
                }
                else
                    notes[name]<<evt.getString();
            }
            else
            {
                if (debug)
                    chout <= "(Client) (debug) Notes listener received END" <= IO.nl();
                onEnd();
                me.exit();
            }
        }
    }
}

// prints the instruments when both the add and the extend listeners
// have returned
fun void onEnd()
{
    chout <= ++numQuit <= " listeners received END" <= IO.nl();
    if (numQuit == 3) // all of them
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
                    chout <= "(Client)[" <= name <= "] " <= messages[name][j].statusbyte+i <= " becomes " <= messages[name][j].addresspattern <= IO.nl();
                else
                    chout <= "(Client)[" <= name <= "] " <= messages[name][j].addresspattern <= " available." <= IO.nl();
            }
            for ( int j; j < notes[instruments[i]].size(); j++ )
            {
                chout <= "(Client)[" <= name <= "] ——— " <= notes[name][j] <= IO.nl();
            }
        }
        
        // and initiate calibration
        doCalibrate();
        // now we can test
        doTests();
    }
}

// does the calibration
fun void doCalibrate()
{
    if (delayList == "")
        chout <= "(Client) No delay calibration specified, not telling the server to do so." <= IO.nl();
    else
    {
        // lots of similarity between this and the tester stuff, should really re use
        if (debug)
            chout <= "(Client) (debug) double checking calibrate list: " <= delayList <= IO.nl();
        splitString(delayList, ",") @=> string toDelay[];
        string actualList;
        
        for (int i; i < toDelay.cap(); i++)
        {
            if (toDelay[i].lower() == "off")
            {
                "off" => actualList;
                break;
            }
            if (toDelay[i].lower() == "on")
            {
                "on" => actualList;
                break;
            }
            
            false => int exists;
            for (int j; j < instruments.cap(); j++)
            {
                if (instruments[j].lower() == toDelay[i].lower())
                {
                    true => exists;
                    if (actualList != "")
                        actualList + "," => actualList;
                    actualList + instruments[j] => actualList;
                    break;
                }
            }
            if (!exists)
            {
                chout <= "(Client) Instrument " <= toDelay[i] <= " not present on server, not asking to calibrate." <= IO.nl();
            }
        }
        chout <= "(Client) asking server to calibrate: " <= actualList <= IO.nl();
        
        osend.startMsg("/system/calibrate", "s");
        osend.addString(actualList);
    }
}

// does the tests
fun void doTests()
{
    if (testList == "")
        chout <= "(Client) No tests specified." <= IO.nl();
    else
    {
        false => canSend; // let's not confuse things
        if (debug)
            chout <= "(Client) (debug) double checking test list: " <= testList <= IO.nl();
        
        splitString(testList, ",") @=> string toTest[];
        string actualList;
        
        for (int i; i < toTest.cap(); i++)
        {
            if (toTest[i].lower() == "all")
            {
                "all" => actualList;
                break;
            }
            false => int exists;
            for (int j; j < instruments.cap(); j++)
            {
                if (instruments[j].lower() == toTest[i].lower())
                {
                    true => exists;
                    if (actualList != "")
                        actualList + "," => actualList;
                    actualList + instruments[j] => actualList;
                    break;
                }
            }
            if (!exists)
            {
                chout <= "(Client) Instrument " <= toTest[i] <= " not present on server, not asking to test." <= IO.nl();
            }
        }
        
        chout <= "(Client) Asking server to test: " <= actualList <= IO.nl();
        
        // actually send
        osend.startMsg("/system/test", "s");
        osend.addString(actualList);
        
        spork~testEndListener();
        while (!canSend)
        {
            if ((now%2::second)/1::samp == 0)
            {
                chout <= ". . ." <= IO.nl();
            }
            1::samp => now;
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
        chout <= "(Client) (debug) Adding standard messages to " <= instruments[inst] <= IO.nl();
    // set up the defaults
    getDefaultMessages(instruments[inst]) @=> MessagePair m[];
    // sync, no explicit locks, have no idea how granular things actually are
    if ( messages[instruments[inst]] == null )
        m @=> messages[instruments[inst]];
    else
        for ( int i; i < m.cap(); i++ )
            messages[instruments[inst]]<<m[i];
    
    if ( notes[instruments[inst]] == null )
        new string[0] @=> notes[instruments[inst]];
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
    newhost => string host;
    if (RegEx.match("^server=", host))
    {
        if (debug)
            chout <= "(Client) (debug) Stripping server= from hostname" <= IO.nl();
        newhost.substring(7) => host;
    }
    if ( hostSet )
    {
        cherr <= "(Client) Error: setting host a second time, ignoring." <= IO.nl();
    }
    else
    {
        chout <= "(Client) Setting host to " <= host <= IO.nl();
        host => hostname;
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
/** Copied from Util.ck */
/** splits the string by the given pattern (not regex, just == )*/
fun string[] splitString( string in, string pattern )
{
    string s[0];
    __split(in, pattern, s);
    return s;
}

/** private recursive call */
fun void __split( string in, string pat, string results[] )
{
    // find the pattern
    in.find( pat ) => int where;
    
    if ( where >= 0 )
    {
        results.size( results.size()+1 );
        in.substring( 0,where ) => results[results.size()-1];
        return __split( in.substring(where + pat.length()), pat, results );
    }
    results.size( results.size()+1 );
    in => results[results.size()-1];
    return;
}


// defines a translation between a midi message and an osc message
private class MessagePair
{
    string addresspattern;
    int statusbyte;
}