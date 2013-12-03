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
    // the number of recognised osc address patterns
    int numPats;
    // holds the MidiMessageContainers by OSC address pattern that should produce them
    MidiMessageContainer @ transform_table[64]; // has some default value, array.push_back() doesn’t work
    
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
        
        // now read in the translations
        string osc_patterns[64];
        while ( file.more() )
        {
            file.readLine() => line;
            int split;
            // find the equals
            while ( line.charAt( split++ ) != '=' && split < line.length() );
            if ( split == line.length() )
            {
                cherr <= "Can’t find the ‘=‘ in this line: " <= line <= IO.nl();
                cherr <= "Can’t initialise" <= IO.nl();
                return;
            }
            
            // if we get here we’re good
            line.substring( 0, split ) => string pat;
            line.substring( split ) => string msg;
            pat => osc_patterns[numPats++];
            
            // grab typetag
            int i;
            while (pat.charAt(i++) != ',');
          
            
            midiContainerFromString( msg, pat.substring(i).trim() ) @=> transform_table[pat];
        }
        
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
        
        for (int i; i < 2; i++)
        {
            if ( bytes[1].charAt(0) != '$' )
            {
                bytes[1].toInt() => d[i].set;
            }
            else
            {
                if (typetag.charAt(0) == 'i') // it is probably i (or should be)
                {
                    MidiDataByte.INT_VAL => d[i].set;
                }
                else if (typetag.charAt(0) == 'f') // warn, but still use
                {
                    MidiDataByte.FLOAT_VAL => d[i].set;
                    cherr <= "Initialising MIDI instrument to translate float into int, this works but may not be ideal" <= IO.nl();
                }
                else 
                    cherr <= "Can’t turn type ‘" <= typetag.charAt(0) <= "’ into midi." <= IO.nl();
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
    }
    
    /** Attempts to open a MIDI port by name, 
    potentially useful for instruments which
    will always present to the system as the 
    same MIDI device */
    fun void setMidiPort( string port ) 
    {
        if ( !mout.open( port ) )
            cherr <= "Error opening port: " <= port <= IO.nl();
    }
}

/** A class representing a piece of midi data that might be an osc arg or might be a set value */
private class MidiDataByte
{
    // keep track - if < 0 must be FLOAT_VAL or INT_VAL 
    int _val;
    
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
        evt => d1.get => msg.data2;
        evt => d2.get => msg.data3;
    }
}