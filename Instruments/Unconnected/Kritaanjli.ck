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
[45,44,30,31,29,32,38,43,33,37,35,34,28,27,26,25,24,36,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0] @=> int actualNotes[];
    
    MidiMsg msg; 
    
    // override the init so MidiInstrument doesn't try read this file
    // it now our responsibility to ensure transform_table gets
    // something for the default messages or we might crash stuff
    fun void init( OscRecv recv, FileIO file )
    {
        "Kritaanjli" => name;
        
        // note
       /* MidiMessageContainer noteMsg;
        MidiDataByte d1, d2;
        MidiDataByte.INT_VAL => d1.set => d2.set;
        noteMsg.set( 144, d1, d2 );
        noteMsg @=> transform_table["/Kritaanjli/note,ii"];
        
        // control
        MidiMessageContainer contMsg;
        MidiDataByte d3, d4;
        MidiDataByte.INT_VAL => d3.set => d4.set;
        contMsg.set( 145, d3, d4 );
        contMsg @=> transform_table["/Kritaanjli/control,ii"];
        
        // noteoff
        MidiMessageContainer offMsg;
        MidiDataByte d5, d6;
        MidiDataByte.INT_VAL => d5.set;
        0 => d6.set;
        offMsg.set( 145, d5, d6 );
        offMsg @=> transform_table["/Kritaanjli/noteoff,ii"];*/
        
        // add nonstandard staus byte so that noteoff gets set up in client
        128 => nonstandard_statusbytes["/Kritaanjli/noteoff,ii"];
        
        // set MIDI port — use chuck ——probe to find the right one (can be a string)
        setMidiPort( 0 );
        
        spork~_noteChecker();
        ["/Kritaanjli/note,ii", "/Kritaanjli/control,ii", "/Kritaanjli/noteoff,ii"] @=> string names[];
        __init( recv, names);
    }
    
    // called when a note comes in
    fun void handleMessage( OscEvent event, string addrPat )
    {
        // unpack the data
        // if it isn't ii it will complain here
        event.getInt() => int d1;
        event.getInt() => int d2;
        if ( addrPat == "/Kritaanjli/note,ii" )
        {
            // turn on solenoid
            // double check range
            if ( (d1 >= 48) && (d1 <= 48 + actualNotes.cap()-1) )
            {
                _outputMidi( 144, actualNotes[d1-48], d2 );
                _polyphony++;
                1 => _doMotor; // can do motor with > 0 notes
            }
        }
        else if ( addrPat == "/Kritaanjli/noteoff,ii" )
        {
            // turn off solenoid
            // double check range
            if ( (d1 >= 48) && (d1 <= 48 + actualNotes.cap()-1) )
            {
                _outputMidi( 144, actualNotes[d1-48], 0 );
                if (_polyphony > 0)
                    _polyphony--;
                noteOff.broadcast();
            }
        }
        else if ( addrPat == "/Kritaanjli/control,ii" )
        {
            // motor control cc7
            if ( d1 == 7 )
            {
                if ( _doMotor )
                {
                    _outputMidi(145,0,d2);
                }
                else
                {
                    _outputMidi(145,0,0); // make sure
                }
            }    
        }
        else
            cherr <= "[Kritaanjli] Unkown message: " <= addrPat <= IO.nl();
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