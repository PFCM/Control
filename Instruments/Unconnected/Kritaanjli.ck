//type=KRITAANJLI
// ^^^^ this is key
/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: Kritaanjli.ck
Desc: specific code for Kritaanjli, the harmonium. Requires that the
motor for the bellows be shut off when no notes are playing.
Essentially a wrapper around Jim Murphy and Ajay Kapur's Harmonium_v02 code
***********************************************************************/

// contains very much code from Ajay Kapur and Jim Murphy 2012
public class Kritaanjli extends MidiInstrument
{
    0 => int _polyphony; // how many notes are on 
    Event noteOff;       // notify other shreds if noteoff
    0 => int _doMotor;   // used to stop explicit setting of motor speed when it shouldn't go
    1::second => dur _motorDelay; // max time we can wait
    
    MidiMsg msg; 
    
    // override the init so MidiInstrument doesn't try read this file
    // it now our responsibility to ensure transform_table gets
    // something for the default messages
    fun void init( OscRecv recv, FileIO file )
    {
        // may as well use the code in MidiInstrument
        MidiMessageContainer msg;
        MidiDataByte d1, d2;
        d1.set(MidiDataByte.INT_VAL);
        
        spork~_noteChecker();
    }
    
    // called when a note comes in
    fun void handleMessage( OscEvent event, string addrPat )
    {
        
    }
    
    fun void _outputMidi( int a, int b, int c )
    {
        a => msg.data1;
        b => msg.data2;
        c => msg.data3;
        mout.send(msg);
    }
    
    fun void _noteChecker()
    {
        while ( true )
        {
            noteOff => now;
            
            if ( _polyphony <= 0 )
            {
                _motorDelay => now;
                0 => _doMotor;
                _outputMidi(145, 0, 0);
            }
        }
    }
}