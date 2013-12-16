
/** A class representing a piece of midi data that might be an osc arg or might be a set value */
private class MidiDataByte
{
    // keep track - if < 0 must be FLOAT_VAL or INT_VAL 
    int _val;
    // used for the order in which they should be executed
    int number;
    
    /** constants so instances know what they are */
    1 => static int CONST_VAL;
    -2 => static int FLOAT_VAL;
    -3 => static int INT_VAL;
    
    /** First integer is a constant either CONST_VAL, FLOAT_VAL or INT_VAL, second is the value (only used if CONST_VAL specified) */
    fun void set( int type, int value )
    {
        if (type < 0)
            type => _val;
        else 
            value => _val;
    }
    /** Sets the type, either CONST_VAL, FLOAT_VAL or INT_VAL, any value >=0 will set type to CONST_VAL and store the value */
    fun void set( int val )
    {
        val => _val;
    }
    
    /** Returns the value represented by this, getting it from the OscEvent if necessary */
    fun int get(OscEvent evt)
    {
        if ( _val == FLOAT_VAL )
            return evt.getFloat() $ int;
        if ( _val == INT_VAL )
            return evt.getInt();
        return _val;
    }
}
