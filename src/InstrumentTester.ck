/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: Server.ck
Desc: Sends a few notes to each instrument. Still at this point up 
to the user to verify everything is in fact working, but at least this
will automatically run through what should be connected. Of course 
a /<name>/note message may or may note trigger a sounding note, it most
likely will and it is probably better to keep this as portable as 
possible.
***********************************************************************/

public class InstrumentTester
{
    [0,2,4,5,7,9,11] @=> int scale[]; // major scale in semitones from the root. Provides some arbitrary data to use.
    
    /** Runs the test, in this case sends
    a couple of random notes across
    all of the possible range to each
    instrument. Probably wise to run 
    this asynchronously because it 
    could take a while. This assumes 
    the instrument has its fail safes 
    built and and won't self destruct 
    with out of range notes, which is 
    kind of the point of this system.*/
    fun void run( Instrument instruments[] )
    {
        OscSend osend;
        osend.setHost( "localhost", 50000 );
        // make a list of the patterns necessary
        string addrpats[instruments.cap()];
        for (int i; i < instruments.cap(); i++)
        {
            "/" + instruments[i].name + "/note" => addrpats[i];
        }
        
        // for each instrument, for each octave
        for (int root; root < 127; 12 +=> root)
        {
            // send a note message to each instrument in turn
            for (int i; i < instruments.cap(); i++)
            {
                osend.startMsg(addrpats[i], "ii");
                root + scale[Math.random2(0,scale.cap()-1)] => int note;
                osend.addInt(note);
                osend.addInt(64);
                chout <= "Sent " <= addrpats[i] <= " with note: " <= note <= IO.nl();
                1::second => now;
                // check for noteoff, jic
                for (int j; j < instruments[i].patterns.cap(); i++)
                {
                    if ( RegEx.match("/noteoff,",instruments[i].patterns[j]))
                    {
                        osend.startMsg("/" + instruments[i].name + "/noteoff", "ii");
                        osend.addInt(note);
                        osend.addInt(64);
                        break;
                    }
                }
            }
        }
        for (127 => int root; root >= 12; 12 -=> root)
        {
            // descend simultaneously (could be pretty handy to test latency compensation)
            root -scale[Math.random2(0,scale.cap()-1)] => int note;
            for (int i; i < instruments.cap(); i++)
            {
                osend.startMsg(addrpats[i], "ii");
                osend.addInt(note);
                osend.addInt(64);
                chout <= "Sent " <= addrpats[i] <= " with note: " <= note <= IO.nl();
            }
            1::second => now;
            for (int i; i < instruments.cap(); i++)
            {
                // check for noteoff, jic
                for (int j; j < instruments[i].patterns.cap(); i++)
                {
                    if ( RegEx.match("noteoff,",instruments[i].patterns[j]))
                    {
                        osend.startMsg("/" + instruments[i].name + "/noteoff", "ii");
                        osend.addInt(note);
                        osend.addInt(64);
                        break;
                    }
                }
            }
        }
    }
}