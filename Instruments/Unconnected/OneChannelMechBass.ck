//type=ONECHANNELMECHBASS

// most of this should use existing framework in Instrument and MidiInstrument

public class OneChannelMechBass extends MultiStringInstrument
{
    // set up info for chooser
    fun int init( OscRecv input, FileIO file )
    {
        
         if (debug)
             chout <= "[OneChannelMechBass] Initialising one channel mechbass" <= IO.nl();
        setNumStrings(4);
        
        [0,1,2,3] @=> int chans[];
        setChannels(chans);
        
        __setName("MechBass");
        
        // mins and maxes
        [44,39,33,28] @=> int mins[]; // the lowest frequencies (GDEA)
        [56,51,46,41] @=> int maxes[]; // the highest notes
        
        setRanges(maxes, mins);
        if (!setMidiPort(1))
            return false; // something
        
        string osc_patterns[0];
        patterns<<"/MechBass/noteoff,ii";
        // and add some handy messages in case you want to just use osc
        // (in which case you could use the other files, but these might be nicer)
        patterns<<"/MechBass/pluck,i";
        patterns<<"/MechBass/position,ii";
        patterns<<"/MechBass/clamp,ii";
        patterns<<"/MechBass/damp,i";
        // might add a function to MidiInstrument to make this less weird
        128 => nonstandard_statusbytes["/MechBass/noteoff,ii"];
        
        
        // might add and addNote function to Instrument to make this a bit less weird
        notes<<"Attempts to choose a string for an oncoming note based on which string that can play the note is the closest to it, breaking ties by which is most comfortably within the range.";
        
        
        return _init( input, patterns );
    }
    
    // overriding this to make use of the MultiStringinstrument.chooseString
    // have to make sure to translate all the osc messages, by overriding this 
    // we are not using the MidiInstrument translation framework
    fun void handleMessage( OscEvent evt, string addrPat )
    {
        MidiMsg msg; 
        if (RegEx.match("/note,", addrPat))
        {
            evt.getInt() => int note;
            evt.getInt() => int vel;
            144 + chooseString(note) => msg.data1;
            note => msg.data2;
            vel => msg.data3;
            mout.send(msg);
        }
        else if (RegEx.match("/noteoff,", addrPat))
        {
            evt.getInt() => int note;
            evt.getInt() => int vel;
            128 + chooseString(note) => msg.data1;
            note => msg.data2;
            vel => msg.data3;
            mout.send(msg);
        }
        else if (RegEx.match("/control,", addrPat))
        {
         // note —— do this
         // intent is to duplicate all the control messages for each
         // string so that you can in fact send them all
         // because it does not make much sense to send individual ones   
        }
        else if (RegEx.match("/pluck,", addrPat))
        {
            // how to just make it pluck?
        }
        else if (RegEx.match("/position,", addrPat))
        {
            evt.getInt() => int which;
            evt.getInt() => int note;
            144 + note => msg.data1;
            note => msg.data2;
            0 => msg.data3;
            mout.send(msg);
        }
        // clamps a given string at a given note
        else if (RegEx.match("/clamp,", addrPat))
        {
            evt.getInt() => int which;
            evt.getInt() => int note;
            144 + which => msg.data1;
            note => msg.data2;
            64 => msg.data3;
            mout.send(msg);
            
        }
        else if (RegEx.match("/damp,", addrPat))
        {
            evt.getInt() => int which;
            128+which => msg.data1;
            64 => msg.data2;
            64 => msg.data3;
            mout.send(msg);
        }
        else
        {
            cherr <= "[MechBass] Received unknown message somehow: " <= addrPat <= IO.nl();
        }
    }
}