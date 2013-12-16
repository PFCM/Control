/** A class to hold midi messages that may require data from an osc message */
public class MidiMessageContainer 
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
        // TODO — same number, get only second one right, match typetags up right
        // this whole section probably needs to be redone
        
        if ( d1.number < d2.number )
        {
            evt => d1.get => msg.data2;
            evt => d2.get => msg.data3;
        } 
        else if ( d1.number > d2.number )
        {
            evt => d2.get => msg.data3;
            evt => d1.get => msg.data2;
        }
        // must be the same, will check they are greater than 0
        else if ( d1.number > 0 )
        {
            // need to double check types line up
            if ( d1.number == 1 )
                evt => d1.get => msg.data2 => msg.data3;
            else if ( d1.number == 2 )
            {
                evt => d1.get; // burn one
                evt => d2.get => msg.data2 => msg.data3;
            }
        }
        else // both <= 0, so now we just need to put in the actual values
        {
            evt => d1.get => msg.data2;
            evt => d2.get => msg.data3;
        }
        
        return msg;
    }
}