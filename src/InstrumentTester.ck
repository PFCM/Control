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
        
        for (int i; i < instruments.cap(); i++)
        {
            "/" + instruments[i].name + "/note"=> string addrpat;
            // for each instrument, for each octave
            chout <= "TESTING: " <= instruments[i].name <= IO.nl();
            for (int root; root < 127; 12 +=> root)
            {
                // send a note message
                osend.startMsg(addrpat, "ii");
                root + scale[Math.random2(0,scale.cap()-1)] => int note;
                osend.addInt(note);
                osend.addInt(64);
                chout <= "        sent note: " <= note <= IO.nl();
                .7::second => now;
            }
            for (127 => int root; root >= 12; 12 -=> root)
            {
                osend.startMsg(addrpat, "ii");
                root -scale[Math.random2(0,scale.cap()-1)] => int note;
                osend.addInt(note);
                osend.addInt(64);
                chout <= "        sent note: " <= note <= IO.nl();
                .7::second => now;
            }
        }
    }
}