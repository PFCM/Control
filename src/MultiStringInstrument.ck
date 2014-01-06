/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: MultiStringInstrument.ck
Desc: A basic instrument abstract class that provides some methods to 
      choose strings based on their ranges and whatnot
***********************************************************************/

// to extend this into a usable instrument
// call setNumStrings and setRanges appropriately to set the internal state
// create an appropriate init() method that calls __init() to set up the OSC
// call setMidiPort() to set the midi output
// use chooseString() to get the channel number to send stuff
public class MultiStringInstrument extends MidiInstrument
{
    // Variables
    int _numStrings;                 // how many strings we actually have
    int _stringMax[0];     // the maximum (highest) MIDI note number per string
    int _stringMin[0];     // the minimum (lowest) MIDI note number per string
    int _stringChannels[0]; // channel for each string
    int _lastString;
    
    // the range of string n is taken to be [_stringMin[n], _stringMax[n]] 
    // note the closed interval - the number in stringMax is included
    
    /* Sets the number of strings and allocates space according, initialising nothing */
    fun void setNumStrings( int num )
    {
        num => _numStrings;
        new int[_numStrings] @=> _stringMax;
        new int[_numStrings] @=> _stringMin;
        new int[_numStrings] @=> _stringChannels;
    }
    /* Sets the number of strings, allocates space and initialises channels going up 
     * by one from the given start.
     */
     fun void setNumStrings( int num, int startChan )
     {
         setNumStrings( num );
         for ( int i; i < num; i++ ) 
         {
             startChan + i => _stringChannels[i];
         }
     }
     
    /* Sets the ranges of the strings, needs an array of the maximums and the minimums. 
     * Copies all the data to ensure the dimensions are correct.
     */
     fun void setRanges( int max[], int min[] )
     {
         // sanity checks
         if ( max.cap() < _numStrings )
         {
             cherr <= "(MultiStringInstrument) Error: given max array has fewer elements than number of strings." <= IO.nl();
             return;
         }
         if ( min.cap() < _numStrings )
         {
             cherr <= "(MultiStringInstrument) Error: given min array has fewer elements than number of strings." <= IO.nl();
             return;
         }
         if ( max.cap() > _numStrings )
         {
             cherr <= "(MultiStringInstrument) Error: given min array has more elements than number of strings." <= IO.nl();
             cherr <= "(MultiStringInstrument)        ignoring the ones above." <= IO.nl();
         }
         if ( min.cap() > _numStrings )
         {
             cherr <= "(MultiStringInstrument) Error: given min array has more elements than number of strings." <= IO.nl();
             cherr <= "(MultiStringInstrument)        ignoring the ones above." <= IO.nl();
         }
             
         for ( int i; i < _numStrings; i++ )
         {
             max[i] => _stringMax[i];
             min[i] => _stringMin[i];
         }
     }
    
    /* returns a number (between 0 and _numStrings-1) which represents the best string to
     * use for the current note. Might try a couple of strategies, but for now will just
     * alternate if it is in range of two.
     */
     fun int chooseString( int note )
     {
         int strings[0];
         // find possible strings
         for (int i; i < _numStrings; i++)
         {
             if (note <= _stringMax[i] && note >= _stringMin[i])
             {
                 strings<<i;
             }
         }
         
         // if there are more than one choose one that isn't the last string
         // perhaps we could set a threshold of a couple of notes from the last note on that
         // string so that you preserve runs?
         if (strings.cap() == 1)
             return strings[0];
         
         for ( int i; i < strings.cap(); i++ )
             if ( strings[i] != _lastString )
             {
                 i => _lastString;
                 return strings[i];
             }
     }
}