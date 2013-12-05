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
    MidiOut mout;
    0 => int portSet;
    // the number of recognised osc address patterns
    int numPats;
    // holds the MidiMessageContainers by OSC address pattern that should produce them
    MidiMessageContainer @ transform_table[0];
    
    fun void init( OscRecv input, FileIO file ) {
        chout <= "Initialising MIDI instrument" <= IO.nl();
        // generic midi instrument uses a table of translations defined
        // in the file
        // assume file has moved past the first line and
        // no more
        file.readLine() => string line;
        if ( line.substring( 0,5 ) != "name=" )
        {
            cherr <= "Expecting: name=something got " <= line <= IO.nl();
            cherr <= "Can’t initialise" <= IO.nl();
            return;
        }
        
        __setName(line.substring(5).trim());
        
        
        
        // now read in the translations/port
        string osc_patterns[0];
        while ( file.more() )
        {
            file.readLine() => line;
            
            
            
            line.find("port=") => int split;
            if (split < 0) // translation
            {
                0 => split;
                // find the equals
                while ( line.charAt( split++ ) != '=' && split < line.length() );
                if ( split == line.length() )
                {
                    cherr <= "Can’t find the ‘=‘ in this line: " <= line <= IO.nl();
                    cherr <= "Can’t initialise" <= IO.nl();
                    return;
                }
                
                // if we get here we’re good
                line.substring( 0, split-1 ) => string pat; // cut off the =
                Util.trimQuotes( pat ) => pat;
                line.substring( split ) => string msg;
                
                // now does the pattern start with the name?
                if ( pat.find( name ) != 1 )
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
                    return;
                }
                
                //chout <= i <= "\t" <= pat.length() <= IO.nl();
                midiContainerFromString( msg, pat.substring(i).trim() ) @=> transform_table[pat];
            }
            else // port=something
            {
                // is it a number?
                line.substring(5) => string port;
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
            cherr <= name <= " — MIDI port not found in file, MIDI not initialised." <= IO.nl();
        
        // finally, call the super init to set up osc
        __init( input, osc_patterns );
    }
    
    /** Creates a MidiMessageContainer from the string assumed to be stripped to just the Midi message descriptor. Also needs the OSC typetag. */
    fun MidiMessageContainer midiContainerFromString( string message, string typetag )
    {
        // TODO have the number after $ specify the order in which they are executed but not the order 
        // of the resulting midi message
        
        
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
                        MidiDataByte.INT_VAL => d[i].set;
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
    fun void setMidiPort( int port ) 
    {
        if ( !mout.open( port ) )
            cherr <= "Error opening port: " <= port <= IO.nl();
        
        1 => portSet;
    }
    
    /** Attempts to open a MIDI port by name, 
    potentially useful for instruments which
    will always present to the system as the 
    same MIDI device */
    fun void setMidiPort( string port ) 
    {
        if ( !mout.open( port ) )
            cherr <= "Error opening port: " <= port <= IO.nl();
        
        1 => portSet;
    }
    
    
    /** Handle a received message.
    This method receives a reference to the OscEvent that just 
    fired and the string used to get that event.
    We have already done most of the hard work determining the 
    typetag etc, so we can just throw it to the appropriate
    container and send the MidiMsg. */
    fun void handleMessage( OscEvent event, string addrPat )
    {
        <<<"received ", addrPat>>>;
        mout.send( transform_table[addrPat].getMsg( event ) );
    }
    
    /** Sends the non-default messages */
    fun void sendMethods( OscSend s )
    {
        Util.makeDefaults( name ) @=> string defaults[];
        for ( int i; i < patterns.cap(); i++ )
        {
            0 => int default;
            for ( int j; j < defaults.cap(); j++ )
            {
                if ( defaults[j] == patterns[i] )
                {
                    1 => default;
                    break;
                }
            }
            if ( !default )
            {
                s.startMsg( "/instrument/extend", "ssi" );
                s.addString( name );
                s.addString( patterns[i] );
                s.addInt( transform_table[patterns[i]].status );
            }
        }
    }
}

/** A class representing a piece of midi data that might be an osc arg or might be a set value */
private class MidiDataByte
{
    // keep track - if < 0 must be FLOAT_VAL or INT_VAL 
    int _val;
    // used for the order in which they should be executed
    int number;
    
    /** constants so instances know what they are */
    1 => static int CONST_VAL;
    -2 => static int FLOAT_VAL;
    -3 => static int INT_VAL;
    
    /** First integer is a constant either CONST_VAL, FLOAT_VAL or INT_VAL, second is the value (only used if CONST_VAL specified) */
    fun void set( int type, int value )
    {
        if (type < 0)
            type => _val;
        else 
            value => _val;
    }
    /** Sets the type, either CONST_VAL, FLOAT_VAL or INT_VAL, any value >=0 will set type to CONST_VAL and store the value */
    fun void set( int val )
    {
        val => _val;
    }
    
    /** Returns the value represented by this, getting it from the OscEvent if necessary */
    fun int get(OscEvent evt)
    {
        if ( _val == FLOAT_VAL )
            return evt.getFloat() $ int;
        if ( _val == INT_VAL )
            return evt.getInt();
        return _val;
    }
}

/** A class to hold midi messages that may require data from an osc message */
private class MidiMessageContainer 
{
    int status;
    MidiDataByte d1, d2;
    
    fun void set( int s, MidiDataByte data1, MidiDataByte data2 )
    {
        s => status;
        data1 @=> d1;
        data2 @=> d2;
    }
    
    fun MidiMsg getMsg( OscEvent evt )
    {
        MidiMsg msg;
        
        status => msg.data1;
        
        if ( d1.number < d2.number )
        {
            evt => d1.get => msg.data2;
            evt => d2.get => msg.data3;
        } 
        else
        {
            evt => d2.get => msg.data3;
            evt => d1.get => msg.data2;
        }
        
        return msg;
    }
}