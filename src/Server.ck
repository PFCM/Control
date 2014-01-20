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

Instrument @ instruments[0]; // array of references, initialises to null rather than default objects as a bit of safety

/*******************BEGIN CUSTOM INSTRUMENT NAMES**********************/

"KRITAANJLI" => string KRITAANJLI;
"ONECHANNELSWIVEL" => string ONECHANNELSWIVEL;
"ONECHANNELMECHBASS" => string ONECHANNELMECHBASS;

/********************END CUSTOM INSTRUMENT NAMES***********************/
// Global OSC receiver, just needs to listen
OscRecv netRecv;
// grab a port outside the registered range
// port is now 50000
50000 => netRecv.port;

// are we in the middle of calibration?
false => int isCalibrating;


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
        if (files[i].charAt(0) == '.')
        {
            cherr <= "File is probably supposed to be hidden. Ignoring." <= IO.nl();
            continue;
        }
        FileIO inst;
        if ( !inst.open( me.dir() + "/../Instruments/" + files[i], FileIO.READ ) )
            cherr <= "Error opening '" <= me.dir() + "/../Instruments/" <= "', ignoring." <= IO.nl();
        else
        {
            if ( inst.isDir() )
            {
                chout <= "Skipping directory " <= files[i] <= IO.nl();
            }
            else // inst.isDir()
            {
                null @=> Instrument @ newI; // reference to instrument, no need to construct because we will jam a subclass in here
                
                inst.readLine() => string output;
                // is the file a .ck or just a config file
                if ( RegEx.match( ".ck$", files[i] ) )
                {
                    if ( ! RegEx.match( "^//", output ) ) // needs to start with //
                    {
                        cherr <= "Found a .ck in Instruments directory without a comment on the first line. Ignoring." <= IO.nl();
                    }
                    else 
                    {
                        output.substring(2).trim() => string type;
                        if ( type.substring(0,5) != "type=" )
                            cherr <= "\t type= must be in the first line of .ck" <= IO.nl();
                        else
                        {
                            // HERE IS WHERE WE FIND SUBCLASSES FOR SPECIFIC INSTRUMENTS
                            // if we get a lot of these it might make more sense to try be a bit more generic
                            type.substring(5) => type;
                            
                            if ( type == KRITAANJLI )
                            {
                                new Kritaanjli @=> newI;
                            }
                            else if ( type == ONECHANNELSWIVEL )
                            {
                                new OneChannelSwivel @=> newI;
                            }
                            else if ( type == ONECHANNELMECHBASS )
                            {
                                new OneChannelMechBass @=> newI;
                            }
                            else
                            {
                                cherr <= "IGNORING unknown instrument type: " <= type <= IO.nl();
                            }
                        }
                    }
                }
                else // not a .ck
                {
                    if ( !RegEx.match("^type=", output) )
                        cherr <= "\t" <= "File must begin with 'type='" <= IO.nl();
                    else
                    {
                        output.substring(5) => string type;
                        // HERE IS WHERE WE CHECK FOR KNOWN TYPES OF INSTRUMENT
                        // CURRENTLY KNOWN
                        // MIDI (MIDIInstrument.ck) -- a generic MIDI instrument
                        if (type == "MIDI")
                        {
                            new MidiInstrument @=> newI; // put a MIDI instrument into it
                        }
                        else
                        {
                            cherr <= "\t" <= "Unkown output type '" <= type <= "'" <= IO.nl();
                            continue;
                        }
                    }
                }
                // now add the instrument
                if ( newI != null )
                {
                    if ( newI.init(netRecv, inst) ) // initialise with the OSC recv and the rest of the file
                    {
                        chout <= newI.name <= " loaded successfully." <= IO.nl();
                        // put it in the list
                        instruments<<newI;
                    }
                    else
                    {
                        cherr <= "Error initialising " <= newI.name <= IO.nl();
                    }
                }
            }
        }
    }
}

netRecv.listen(); // now we want to hear
// need somewhere to keep the clients
Client clients[0];

// add the client loop
spork~newClientListener();
// add the test loop
spork~testInstrumentsListener();
// add the calibrate loop
spork~calibrateLatencyListener();

fun void newClientListener()
{
    netRecv.event("/system/addme, si") @=> OscEvent evt;
    chout <= "Listening for new clients" <= IO.nl();
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            evt.getString() => string sendIp;
            evt.getInt() => int sendPort;
            Client s;
            s.setHost( sendIp, sendPort );
            chout <= "Found new client at " <= sendIp <= ":" <= sendPort <= IO.nl();
            sendInstruments( s );
            if (isCalibrating)
            {
                s.startMsg("/system/calibrate/running", "");
            }
            
            // definitely re send, but only add if we don't already have it in the list
            // becasue otherwise the calibrate and whatnot will send twice, this
            // can cause client side issues.
            // have to linearly search the list now.
            true => int add;
            for (int i; i < clients.cap(); i++)
            {
                if ( (clients[i].hostname == sendIp) && (clients[i].port == sendPort) )
                {
                    false => add; // already here
                    break;
                }
            }
            if (add)
                clients << s;
        }
    }
}

/** Listens for a message telling the server to test the instruments */
fun void testInstrumentsListener()
{
    netRecv.event("/system/test,s") @=> OscEvent evt;
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            if (isCalibrating)
            {
                chout <= "Test request received while calibrating, ignoring" <= IO.nl();
                continue;
            }
            chout <= "Beginning tests.." <= IO.nl();
            
            // Construct list of instruments based on comma separated list we just received
            (evt.getString(), ",") => Util.splitString @=> string toTest[];
            Instrument @ test[0];
            InstrumentTester it;
            if (toTest[0] != "all")
            {
                for (int i; i < toTest.cap(); i++)
                {
                    false => int found;
                    for (int j; j < instruments.cap(); j++)
                    {
                        if (instruments[j].name == toTest[i])
                        {
                            test<<instruments[j];
                            true => found;
                            break;
                        }
                    }
                    if (!found)
                    {
                        chout <= "Could not find instrument: " <= toTest[i] <= " must not be plugged in/exist." <= IO.nl();
                    }
                }
                // we probably don't want to allow two tests running at the same time
                // could roll a mutex
                // could have this loop block until it finishes (probably easiest)
                it.run(test);
            }
            else
            {
                it.run(instruments);
            }
            chout <= "Tests finished." <= IO.nl();
            for (int i; i < clients.cap(); i++)
            {
                clients[i].startMsg("/system/test/end", "");
            }
        }
    }
}

/** Listens for an OSC message telling the server to re calibrate the delays */
fun void calibrateLatencyListener()
{
    netRecv.event("/system/calibrate,s") @=> OscEvent evt;
    
    while ( evt => now )
    {
        while ( evt.nextMsg() )
        {
            evt.getString() => string msg;
            if (msg == "off")
            {
                chout <= "LATENCY CALIBRATION OFF" <= IO.nl();
                for (int i; i < instruments.cap(); i++)
                    instruments[i].setDelay(0::ms);
                continue;
            }
            
            chout <= "BEGINNING LATENCY CALIBRATION" <= IO.nl();
            true => isCalibrating;
            // tell the clients we are starting so they can be quiet
            for (int i; i < clients.cap(); i++)
            {
                clients[i].startMsg("/system/calibrate/beginning", "");
            }
            // make a list of instruments
            Util.splitString(msg,",") @=> string list[];
            Instrument @ insts[0];
            
            if (list[0] == "on")
                instruments @=> insts;
            else
            {
                for (int i; i < list.cap(); i++)
                {
                    false => int found;
                    for (int j; j < instruments.cap(); j++)
                    {
                        if (instruments[j].name == list[i])
                        {
                            insts << instruments[j];
                            true => found;
                            break;
                        }
                    }
                    if (!found)
                    {
                        chout <= "Could not find " <= list[i] <= " to calibrate" <= IO.nl();
                    }
                    
                }
            }
            // now we have the actual instruments
            // we have to send them a message, start timing until we 
            //a) reach a maximum threshold or b) hear enough sound
            dur delays[insts.cap()];
            OscSend selfSend;
            selfSend.setHost("localhost", 50000);
            
            // set up signal processing chain
            adc => FFT fft =^ Flux flux => blackhole;
            fft =^ RMS rms => blackhole;
            
            for (int i; i < insts.cap(); i++)
            {
                getLatency(insts[i], selfSend, flux, rms) => delays[i];
                if (delays[i] == 1::second)
                {
                    chout <= "Unable to get response for " <= insts[i].name <= "; either not plugged in or absurdly slow, assuming 0 latency." <= IO.nl();
                    0::ms => delays[i];
                }
                chout <= "Determined latency of " <= delays[i]/1::ms <= " ms for " <= insts[i].name <= IO.nl();
            }
            // now we find the maximum
            0::ms => dur max;
            for (int i; i < insts.cap(); i++)
            {
                if (delays[i] > max)
                    delays[i] => max;
                insts[i].setDelay(delays[i]); // store delays here for now
            }
            
            // now loop every instrument and set the delay to max - its current delay
            for (int i; i < instruments.cap(); i++)
            {
                instruments[i].setDelay(max-instruments[i].delay);
            }
            
            // now we are done
            chout <= "ENDING LATENCY CALIBRATION" <= IO.nl();
            false => isCalibrating;
            // tell the clients to go back to normal
            for (int i; i < clients.cap(); i++)
            {
                clients[i].startMsg("/system/calibrate/end", "");
            }
        }
    }
}

// Attempts to send a note to the given Instrument and listen to the default adc until either spectral flux or RMS reaches a threshold
fun dur getLatency( Instrument instrument, OscSend send, Flux flux, RMS rms )
{
    // make sure the instrument is not already applying delay
    instrument.setDelay(0::ms);
    // in order to ensure we get a note, we're going to have to cover the full range. Then we can take
    // the mean of successful results
    1::second => dur maximum;
    // grab the address patter
    "/" + instrument.name + "/note" => string pattern;
    // does instrument need a noteoff ?
    "" => string offPattern;
    for (int i; i < instrument.patterns.cap(); i++)
    {
        if (RegEx.match("/noteoff,", instrument.patterns[i]));
        {
            chout <= "Assuming " <= instrument.name <= " needs noteoff" <= IO.nl();
            "/" + instrument.name + "/noteoff" => offPattern;
            break;
        }
    }
    
    
    dur times[0];
    
    for (int i; i < 127; 12 +=> i)
    {
        // set up the message to send when the velocity is added
        send.startMsg(pattern, "ii");
        send.addInt(i);
        // grab the time
        now => time start;
        // send the msg and start listening
        send.addInt(64);
        while(rms.fval(0)*100 < 0.1 || flux.fval(0) < 0.8)
        {
            1024::samp => now;
            flux.upchuck();
            rms.upchuck();
            
            if ((now-start) >= maximum)
            {
                break;
            }
        }
        now - start => dur t;
        if (t < maximum)
            times << t;
        
        if (offPattern.length() > 0)
        {
            chout <= "sent noteoff" <= IO.nl();
            send.startMsg(offPattern, "ii");
            send.addInt(i);
            send.addInt(64);
            500::ms => now; // in case of tail
        }
        200::ms => now;
    }
    if (times.cap() == 0)
        return maximum;
    dur total;
    // take the mean of the successful results
    for (int i; i < times.cap(); i++) {
        times[i] +=> total;
    }
    
    return total/times.cap();
}

fun void sendInstruments( Client s )
{
    chout <= "Sending " <= instruments.size() <= " instruments to new client" <= IO.nl();
    for ( int i; i < instruments.size(); i++ )
    {
        s.startMsg( "/system/instruments/add", "s" );
        s.addString( instruments[i].name );
        Util.makeDefaults( instruments[i].name ) @=> string defaults[];
        // add its methods, if they are special
        instruments[i].sendMethods( s.oscSend );
        instruments[i].sendNotes( s.oscSend );
    }
    s.startMsg( "/system/instruments/add", "s" );
    s.addString("END");
    s.startMsg( "/system/instruments/extend", "ssi" );
    s.addString("END");
    s.addString("END");
    s.addInt(-1);
    s.startMsg( "/system/instruments/note", "ss" );
    s.addString("END");
    s.addString("END");
    chout <= "Finished sending instruments" <= IO.nl();
}

// loop
while ( true ) 1::second => now;

// ChucK OscSend provides a setHost() but no way to get that info back.
// Here we define a wrapper around it that gives us this functionality.
private class Client // if we could call methods on the super we could extend it
{
    OscSend oscSend;
    string hostname;
    int port;
    
    fun void setHost(string newhost, int newport)
    {
        newhost => hostname;
        newport => port;
        oscSend.setHost(hostname, port);
    }
    
    fun void startMsg(string pattern, string typetag)
    {
        oscSend.startMsg(pattern, typetag);
    }
    fun void addInt(int i)
    {
        oscSend.addInt(i);
    }
    fun void addFloat(float i)
    {
        oscSend.addFloat(i);
    }
    fun void addString(string i)
    {
        oscSend.addString(i);
    }
}