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
***********************************************************************/

public class Kritaanjli extends MidiInstrument
{
    
    // override the init so MidiInstrument doesn't try read this file
    // it now our responsibility to ensure transform_table gets
    // something for the default messages
    fun void init( OscRecv recv, FileIO file )
    {
        
    }
    
    // override this for now just to stop it crashing
    fun void sendMethods( OscSend s )
    {
        
    }
}