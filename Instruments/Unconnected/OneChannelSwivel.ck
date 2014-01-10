//type=ONECHANNELSWIVEL

public class OneChannelSwivel extends MultiStringInstrument
{
    // need to set ranges and number of strings in init
    fun int init( OscRecv input, FileIO file )
    {
        setNumStrings(6,0);
        // set minimum and maximum ranges (in midi notes, these will have to be determined)
        // this approach will not scale well to a great number of strings, but should be fine for a practical number (ie 6)
       
       // not the real numbers, justsome filler to see if this biz works
        [40,45,50,55,59,64] @=> int mins[];
        [52,57,62,67,71,76] @=> int maxs[];
        
        setRanges(maxs,mins);
        
        __setName("OneChannelSwivel");
        
        
        // get set up for osc,both midis etc
        string osc_patterns[0];
        patterns<<"/pluck,ii";
    }
    
    
}