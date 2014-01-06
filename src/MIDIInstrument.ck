/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: MIDIIInstrument.ck
Desc: Base class for all instruments that output MIDI.
***********************************************************************/

public class MidiInstrument extends Instrument {
    false => int debug;
    MidiOut mout;
    0 => int portSet;
    // the number of recognised osc address patterns
    int numPats;
    // holds the MidiMessageContainers by OSC address pattern that should produce them
    MidiMessageContainer @ transform_table[0];
    // holds the client messages by OSC adress pattern — these are needed for when we enumerate ourselves to the client
    // we only need the non-standard messages here
    int nonstandard_statusbytes[0];
    
    fun int init( OscRecv input, FileIO file ) {
        chout <= "Initialising MIDI instrument" <= IO.nl();
        // generic midi instrument uses a table of translations defined
        // in the file
        // assume file has moved past the first line and
        // no more
        file.readLine() => string line;
        if (line.charAt(0) == '#')
            file.readLine() => string line;
        line => Parser.parseName => string name;
        if ( name == "" )
        {
            cherr <= "Error parsing name - can not initialise MIDI instrument" <= IO.nl();
            return 0;
        }        
        __setName(name);
        
        
        // now read in the translations/port
        string osc_patterns[0];
        while ( file.more() )
        {
            file.readLine() => line;
            // get rid of whole line comments and empty lines
            if (line.length() == 0 || (line.length() > 0 && line.charAt(0) == '#'))
                continue;
            
            // strip comments (if present) from the end of a line
            Util.stripComments(line).trim() => line;
            
            line.find("port=") => int split;
            if (split < 0) // translation
            {
                if ( Parser.isNote(line) )
                {
                    notes<<Parser.parseNote(line);
                    continue;
                }
                
                Util.splitString( line, "=" ) @=> string parts[];
                string pat;
                -1 => int stat;
                
                if ( parts.cap() == 2 )
                    parts[0] => pat;
                else if ( parts.cap() == 3 )
                {
                    parts[1] => pat;
                    // TODO check it is actually OK
                    parts[0].toInt() & 0xf0 => stat; // be agnostic to channel
                }
                else
                {
                    cherr <= "This is not a valid line: " <= line <= IO.nl();
                    cherr <= "Attempting to ignore." <= IO.nl();
                    continue;
                }
                
                Util.trimQuotes( pat ) => pat;
                parts[parts.cap()-1] => string msg;
                
                
                
                // now does the pattern start with /name?
                if ( pat.find( "/" + name ) != 0 )
                {
                    // prepend it
                    "/" + name + pat => pat;
                }
                osc_patterns << pat;
                numPats++;
                
                // grab typetag
                int i;
                while (pat.charAt(i++) != ',' && i < pat.length());
                
                if (i >= pat.length() )
                {
                    cherr <= "(" <= name <= ") Osc message does not appear to have a typetag: " <= pat <= IO.nl();
                    return 0;
                }
                
                //chout <= i <= "\t" <= pat.length() <= IO.nl();
                pat.substring(i).trim() => string tt;
                
                midiContainerFromString( msg, tt ) @=> transform_table[pat];
                if ( !RegEx.match( "/note,", pat ) && !RegEx.match( "/control,", pat ) )
                {
                    // to actually send it to the client as a message it has to have the correct typetag
                    if (tt != "ii")
                    {
                        chout <= "Non standard message with typetag other than ii cannot be used for client MIDI" <= IO.nl();
                        -1 => stat;
                    }
                    chout <= "Added non standard message: " <= pat <= " with midi status byte: " <= stat<= IO.nl();
                    stat => nonstandard_statusbytes[pat];
                }
            }
            else // port=something
            {
                // is it a number?
                line.substring(5) => string port;
                chout <= "Setting port to " <= port <= IO.nl();
                if (RegEx.match("[0-9]+", port))
                {
                    setMidiPort(port.toInt());
                } 
                else
                {
                    setMidiPort(Util.trimQuotes(port));
                }
            }
        }
        
        if(!portSet)
        {
            cherr <= name <= " — MIDI port not found in file, MIDI not initialised." <= IO.nl();
            return 0;
        }
        
        // super sets up default listeners for /note and /control
        // but if we do nothing that will just crash the listener shred
        // because there is nothing in here
        
        
        // check if defaults are specified
        checkDefaults( osc_patterns );
        
        
        // finally, call the super init to set up osc
        return _init( input, osc_patterns );
    }
    
    /** Checks to see if the defaults are specified, adds them if not */
    fun void checkDefaults( string osc_patterns[] )
    {
        // check
        -1 => int noteSet => int contSet;
        for ( int i; i < osc_patterns.cap(); i++ )
        {
            if ( RegEx.match( "^/"+name+"/note,", osc_patterns[i] ) )
            {
                i => noteSet;
                chout <= "Overridden default note listener (found " <= osc_patterns[i] <= ")" <= IO.nl();
            }
            if ( RegEx.match( "^/"+name+"/control,", osc_patterns[i] ) )
            {
                i => contSet;
                chout <= "Overridden default control listener (found " <= osc_patterns[i] <= ")" <= IO.nl();
            }
        }
        
        // not found
        if ( noteSet == -1 )
        {
            // make a message container
            midiContainerFromString( "144,$1,$2", "ii" ) @=> transform_table["/" + name + "/note,ii"];
            chout <= "Made default message for /" <= name <= "/note -> now becomes 144,$1,$2" <= IO.nl();
        }
        
        if ( contSet == -1 )
        {
            midiContainerFromString( "176,$1,$2", "ii" ) @=> transform_table["/" + name + "/control,ii"];
            chout <= "Made default message for /" <= name <= "/control -> now becomes 176,$1,$2" <= IO.nl();
            
        }
    }
    
    /** Creates a MidiMessageContainer from the string assumed to be stripped to just the Midi message descriptor. Also needs the OSC typetag. */
    fun MidiMessageContainer midiContainerFromString( string message, string typetag )
    {
        // TODO have the number after $ specify the order in which they are executed but not the order 
        // of the resulting midi message
        // —— kinda done
        
        // get the three sections individually
        Util.splitString( message, "," ) @=> string bytes[];
        if ( bytes.cap() > 3 )
        {
            cherr <= "Too many bytes for midi message, expect three got: " <= bytes.cap() <= IO.nl();
        }
        bytes[0].toInt() => int status;
        MidiDataByte d[2];
        for (int i; i < bytes.cap()-1; i++)
        {
            
            if ( bytes[i+1].charAt(0) != '$' )
            {
                bytes[i+1].toInt() => d[i].set;
            }
            else
            {
                if ( bytes[i+1].charAt(1) == '1' || bytes[i+1].charAt(1) == '2' && bytes[i+1].length() == 2)
                {
                    if (typetag.charAt(0) == 'i') // it is probably i (or should be)
                    {
                        MidiDataByte.INT_VAL => d[i].set; // bug here — chuck assertion fail
                        bytes[i+1].substring(1).toInt() => d[i].number;
                    }
                    else if (typetag.charAt(0) == 'f') // warn, but still use
                    {
                        MidiDataByte.FLOAT_VAL => d[i].set;
                        bytes[i+1].substring(1).toInt() => d[i].number;
                        cherr <= "Initialising MIDI instrument to translate float into int, this works but may not be ideal" <= IO.nl();
                    }
                    else 
                        cherr <= "Can’t turn type ‘" <= typetag.charAt(0) <= "’ into midi." <= IO.nl();
                    
                    
                }
                else
                {
                    cherr <= "Invalid specifier in MIDI output message: " <= bytes[i+1] <= IO.nl();
                }
            }
        }
        MidiMessageContainer mCont;
        mCont.set( status, d[0], d[1] );
        return mCont;
    }
    
    /** Attempts to open a MIDI port, using a number,
    potentially useful for instruments using hardware MIDI */
    fun int setMidiPort( int port ) 
    {
        mout.open( port ) => portSet;
        if ( !portSet )
            cherr <= "Error opening port: " <= port <= IO.nl();
        
        return portSet;
    }
    
    /** Attempts to open a MIDI port by name, 
    potentially useful for instruments which
    will always present to the system as the 
    same MIDI device */
    fun int setMidiPort( string port ) 
    {
        mout.open( port ) => portSet;
        if ( !portSet )
            cherr <= "Error opening port: " <= port <= IO.nl();
        
        return portSet;
    }
    
    
    /** Handle a received message.
    This method receives a reference to the OscEvent that just 
    fired and the string used to get that event.
    We have already done most of the hard work determining the 
    typetag etc, so we can just throw it to the appropriate
    container and send the MidiMsg. */
    fun void handleMessage( OscEvent event, string addrPat )
    {
        if (debug)
            chout <= "received: " <= addrPat <= IO.nl();
        if (transform_table.find(addrPat))
        {
            transform_table[addrPat].getMsg( event ) @=> MidiMsg @ msg;
            if ( msg != null )
            {
                if (debug)
                    chout <= "sending MIDI " <= msg.data1 <= "," <= msg.data2 <= "," <= msg.data3 <= IO.nl();
                mout.send( msg );
            }
        } 
        else
        {
            chout <= "Unknown message " <= addrPat <= " received by " <= name <= IO.nl();
        }
    }
    
    /** Sends the non-default messages */
    fun void sendMethods( OscSend s )
    {
        chout <= name <= " sending methods." <= IO.nl();
        for ( int i; i < patterns.cap(); i++ )
        {
            0 => int default;
            for ( int j; j < 2; j++ )
            {
                if ( Util.isDefault( patterns[i] ) )
                {
                    1 => default;
                    break;
                }
            }
            if ( !default )
            {
                chout <= "Sending: " <= patterns[i] <= " from " <= nonstandard_statusbytes[patterns[i]] <= IO.nl();
                s.startMsg( "/system/instruments/extend", "ssi" );
                s.addString( name );
                s.addString( patterns[i] );
                s.addInt( nonstandard_statusbytes[patterns[i]] );
            }
        }
    }
    /** sends any notes */
    fun void sendNotes( OscSend s )
    {
        chout <= name <= " sending notes." <= IO.nl();
        for ( int i; i < notes.cap(); i++ )
        {
            s.startMsg("/system/instruments/note","ss");
            s.addString( name );
            s.addString( notes[i] );
        }
    }
}