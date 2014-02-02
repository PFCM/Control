//type=ONECHANNELSWIVEL

public class OneChannelSwivel extends MultiStringInstrument
{
    int currentNotes[6]; // what the actual current notes are, so that we can route the note offs
    
    
    // need to set ranges and number of strings in init
    fun int init( OscRecv input, FileIO file )
    {
        true => debug;
        
        if (debug)
            chout <= "[OneChannelSwivel] is initialising." <= IO.nl();
        setNumStrings(6);
        [0,1,2,3,4,5] @=> int chans[];
        setChannels(chans);
        // set minimum and maximum ranges (in midi notes, these will have to be determined)
        // this approach will not scale well to a great number of strings, but should be fine for a practical number (ie 6)
        
        // currently somewhat detuned
        //G1  C#2 ??? A#2 D3  G#3
        [31, 37, 41, 46, 50, 56] @=> int mins[];
        //C3  E3  ??? D#4 G#4 C5
        [48, 52, 56, 63, 68, 72] @=> int maxs[];
        
        setRanges(maxs,mins);
        setAlgorithm(MultiStringInstrument.CHOOSER_POLYPHONIC);
        setTieBreaker(MultiStringInstrument.BREAK_UP); // break toward higher range, Swivel is more accurate at lower notes so we want to favour them.
        
        __setName("Swivel");
        if (!setMidiPort("Express 128  Port 2")) // for testing
            return false; // USE A NAME
        
        // get set up for osc,both midis etc
        string osc_patterns[0];
        // some handy messages for pure osc use
        osc_patterns<<"/Swivel/pluck,i"; // should specifically send cc 7 with a big number (note, check)
        osc_patterns<<"/Swivel/clamp,ii"; // clamp given string a certain amount (cc 8)
        osc_patterns<<"/Swivel/damp,i"; // damps given string (cc9)
        // doesn't make sense to accept pitchbend as it wouldn't make sense to run autotune
        // on the client because the channels would be all jacked up
        // but we could do with a note off which could damp and maybe raise the clamp
        osc_patterns<<"/Swivel/noteoff,ii";
        128 => nonstandard_statusbytes["/Swivel/noteoff,ii"];
        
        // Add a note
        notes << "Attempts to choose a string for Swivel. Uses an algorithm that should favour
        more polyphonic results. Requires SwivelAutotune to be running on the SERVER";
        
        
        return _init(input, osc_patterns);
    }
    
    // override the event handler to choose strings properly
    fun void handleMessage( OscEvent evt, string addrPat )
    {
        MidiMsg msg; 
        if (RegEx.match("/note,", addrPat))
        {
            evt.getInt() => int note;
            evt.getInt() => int vel;
            handleNote(note, vel);
        }
        else if (RegEx.match("/noteoff,", addrPat)) // CC 9
        {
            evt.getInt() => int note;
            evt.getInt() => int vel;
            handleNoteOff(note, vel);
        }
        else if (RegEx.match("/control,", addrPat))
        {
            // HOW TO DO THIS??????? 
            // how do we know where to send control messages
            // 
        }
        else if (RegEx.match("/pluck,", addrPat)) // CC 7
        {
            176 + _stringChannels[evt.getInt()] => msg.data1;
            7 => msg.data2;
            127 => msg.data3;
        }
        // clamps (or releases) a given string wherever it happens to be 
        else if (RegEx.match("/clamp,", addrPat)) // CC 8
        {
            evt.getInt() => int which;
            176 + _stringChannels[which] => msg.data1;
            8 => msg.data2;
            5 => msg.data3;
            mout.send(msg);
            
        }
        else if (RegEx.match("/damp,", addrPat)) // CC 9
        {
            evt.getInt() => int which;
            176+_stringChannels[which] => msg.data1;
            9 => msg.data2;
            64 => msg.data3; // WHAT SHOULD THIS BE????
            mout.send(msg);
        }
        else
        {
            cherr <= "[Swivel] Received unknown message somehow: " <= addrPat <= IO.nl();
        }
        
    }
    
    fun void handleNote(int note, int vel)
    {
        if (debug)
            chout <= "[OneChannelSwivel] Handling note: " <= note <= " : " <= vel <= IO.nl();
        note => chooseString => int which;
       if (which == -1)
        {
            if (debug)
                chout <= "[OneChannelSwivel] no string available" <= IO.nl();
            return;
        } 
        if (debug)
            chout <= "[OnechannelSwivel] chose string: " <= which <= IO.nl();
        
        // most of them clamp
        MidiMsg clamp;
        176+which => clamp.data1;
        8 => clamp.data2;
        5 => clamp.data3;
        // and a msg for the actual note
        MidiMsg move;
        144+which => move.data1;
        note => move.data2;
        vel => move.data3;
        
        // and to pick
        MidiMsg pick;
        176+which => pick.data1;
        7 => pick.data2;
        127 => pick.data3;
        // now we switch on velocity
        if (vel == 0) // no pick, just clamp and slide
        {
            // first ensure clamp
            mout.send(clamp);
            // and now slide
            mout.send(move);
        }
        else if (vel < 64) // move, clamp, pick
        {
            mout.send(move);
            // now wait
            200::ms => now;
            mout.send(clamp);
            // and pick
            mout.send(pick);
        }
        else // move, clamp, undamp, pick
        {
            mout.send(move);
            // now wait
            200::ms => now;
            mout.send(clamp);
            // undamp
            9 => clamp.data2;
            0 => clamp.data3;
            mout.send(clamp);
            // and pick
            mout.send(pick);
        }
        
        // tidy up the state
        for (int i; i < _stringChannels.cap(); i++)
        {
            if (_stringChannels[i] == which)
            {
                note => currentNotes[i];
                break;
            }
        }
        
    }
     
    fun void handleNoteOff(int note, int vel) // damp, unclamp
    { 
        if (debug)
            chout <= "[OneChannelSwivel] handling note off - " <= note <= " : " <= vel <= IO.nl();
        -1 => int which;
        for (int i; i <  currentNotes.cap(); i++)
        {
            if (currentNotes[i] == note)
            {
                _stringChannels[i] => which;
                break;
            }
        }
        
        if (which == -1)
        {
            if(debug)
                chout <= "[Swivel] received note off for a note I don't have on??" <= IO.nl();
            return;
        }
        
        MidiMsg damp;
        176+which => damp.data1;
        9 => damp.data2;
        vel => damp.data3;
        
        if (vel == 0)
        {
            // do nothing
        }
        else if (vel < 64) // damp, do not raise clamp
        {
            mout.send(damp);
        }
        else // damp, raise clamp
        {
            mout.send(damp);
            // and now raise clamp
            0 => damp.data3;
            8 => damp.data2;
            mout.send(damp);
        }
    }
    
}