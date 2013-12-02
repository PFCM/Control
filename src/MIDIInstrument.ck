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
    
    fun void init(OscRecv input, FileIO file) {
        chout <= "Initialising MIDI instrument" <= IO.nl();
        __init(input, file);
    }
    
    /** Attempts to open a MIDI port, using a number,
        potentially useful for instruments using hardware MIDI */
    fun void setMidiPort( int port ) {
        if ( !mout.open( port ) )
                cherr <= "Error opening port: " <= port <= IO.nl();
    }
    
    /** Attempts to open a MIDI port by name, 
        potentially useful for instruments which
        will always present to the system as the 
        same MIDI device */
    fun void setMidiPort( string port ) {
        if ( !mout.open( port ) )
            cherr <= "Error opening port: " <= port <= IO.nl();
    }
}