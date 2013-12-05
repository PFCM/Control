/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: Server.ck
Desc: contains the loop for the server; populates a list of 
instruments and sets them up receiving OSC and sending
whatever they send.
***********************************************************************/

Instrument @ instruments[0]; // array of references, initialises to null rather than default objects

// Global OSC receiver, just needs to listen
OscRecv netRecv;
// grab a port outside the registered range
// port is now 50000
50000 => netRecv.port;


// Get all the files, this will tell us what robots to load
FileIO dir;
if ( !dir.open( me.dir() + "/../Instruments", FileIO.READ ) )
    cherr <= "Could not open '" <= me.dir()+"/../Instruments" <= "' no files loaded." <= IO.nl();
else
{
    dir.dirList() @=> string files[];
    chout <= "Loading files" <= IO.nl();
    // load the files, add an instrument each
    for ( int i; i < files.cap(); i++ )
    {
        chout <= "File: " <= files[i] <= IO.nl();
        FileIO inst;
        if ( !inst.open( me.dir() + "/../Instruments/" + files[i], FileIO.READ ) )
            cherr <= "Error opening '" <= me.dir() + "/../Instruments/" <= "', ignoring." <= IO.nl();
        else
        {
            
            inst.readLine() => string output;
            // is the file a .ck or just a config file
            if ( RegEx.match( ".*\\.ck", files[i] ) )
            {
                if ( ! RegEx.match( "^//", files[i] ) ) // needs to start with //
                    cherr <= "Found a .ck in Instruments directory without a comment on the first line. Ignoring." <= IO.nl();
                else
                {
                    output.substring(2).trim() => string type;
                    if ( type.substring(0,5) != "type=" )
                        cherr <= "\t type= must be in the first line of .ck" <= IO.nl();
                    else
                    {
                        // HERE IS WHERE WE FIND SUBCLASSES FOR SPECIFIC INSTRUMENTS
                        type.substring(5) => type;
                        
                        /* if ( type == XXXXX )
                            do something
                        */
                    }
                }
            }
            else
            {
                if (output.substring(0,5) != "type=")
                    cherr <= "\t" <= "File must begin with 'type='" <= IO.nl();
                else
                {
                    output.substring(5) => string type;
                    null @=> Instrument @ newI; // reference to instrument, no need to construct because we will jam a subclass in here
                    // HERE IS WHERE WE CHECK FOR KNOWN TYPES OF INSTRUMENT
                    // CURRENTLY KNOWN
                    // MIDI (MIDIInstrument.ck) -- a generic MIDI instrument
                    if (type == "MIDI")
                    {
                        new MidiInstrument @=> newI; // put a MIDI instrument into it
                        /*TEMP
                        m.setMidiPort(0);
                        m @=> newI;*/
                    }
                    else
                    {
                        cherr <= "\t" <= "Unkown output type '" <= type <= "'" <= IO.nl();
                        break;
                    }
                    
                    
                    newI.init(netRecv, inst); // initialise with the OSC recv and the rest of the file
                    // put it in the list
                    instruments.size(instruments.size()+1);
                    newI @=> instruments[instruments.size()-1];
                }
            }
        }
    }
}

netRecv.listen(); // now we want to hear
// need somewhere to keep the clients
OscSend clients[0];

// add the client loop
spork~newClientListener();

fun void newClientListener()
{
    netRecv.event("/system/addme, si") @=> OscEvent evt;
    chout <= "Listening for new clients" <= IO.nl();
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            // TODO check if already exists
            evt.getString() => string sendIp;
            evt.getInt() => int sendPort;
            OscSend s;
            s.setHost( sendIp, sendPort );
            spork~sendInstruments( s );
            clients << s;
        }
    }
}

fun void sendInstruments( OscSend s )
{
    for ( int i; i < instruments.size(); i++ )
    {
        s.startMsg( "/instruments/add", "s" );
        s.addString( instruments[i].name );
        Util.makeDefaults( instruments[i].name ) @=> string defaults[];
        // add its methods, if they are special
        instruments[i].sendMethods( s );
    }
    s.startMsg( "/instruments/add", "s" );
    s.addString("END");
}

// loop
while ( true ) 1::second => now;