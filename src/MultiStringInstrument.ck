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
    int _lastNotes[0];
    
    // the range of string n is taken to be [_stringMin[n], _stringMax[n]] 
    // note the closed interval - the number in stringMax is included
    
    /* Sets the number of strings and allocates space according, initialising nothing */
    fun void setNumStrings( int num )
    {
        num => _numStrings;
         if (debug)
             chout <= "[MultiStringInstrument] allocating space" <= IO.nl();
        new int[_numStrings] @=> _stringMax;
        new int[_numStrings] @=> _stringMin;
        new int[_numStrings] @=> _stringChannels;
        new int[_numStrings] @=> _lastNotes;
        for (int i; i < _lastNotes.cap(); i++)
            1000 => _lastNotes[i];
         if (debug)
             chout <= "[MultiStringInstrument] allocated space" <= IO.nl();
    }
    /* Sets the number of strings, allocates space and initialises channels going up 
     * by one from the given start.
     */
     fun void setNumStrings( int num, int startChan )
     {
         if (debug)
             chout <= "[MultiStringInstrument] Setting channels" <= IO.nl();
         setNumStrings( num );
         if (debug)
             chout <= "[MultiStringInstrument] filling channels" <= IO.nl();
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
    
    /* returns a channel for the best string to
     * use for the current note. Might try a couple of strategies.
     */
     fun int chooseString( int note )
     {
         int strings[0];
         // find possible strings
         if (debug)
             chout <= "[MultiString] Possible String: " <= IO.nl();
         for (int i; i < _numStrings; i++)
         {
             if (note <= _stringMax[i] && note >= _stringMin[i])
             {
                 strings<<i;
                 if (debug)
                     chout <= "\t" <= i <= IO.nl();
             }
         }
         
         // if there are more than one choose the one that is the closest     
         // TODO resolve ties better (choose one nearest the centre of its range?)    
         if (strings.cap() == 1)
             return _stringChannels[strings[0]];
         
         256 => int dist;
         -1 => int closest;
         for ( int i; i < strings.cap(); i++ )
         {
             if ( Math.abs(_lastNotes[strings[i]] - note) < dist )
             {
                 Math.abs(_lastNotes[strings[i]] - note) => dist;
                 i => closest;
                 if (debug)
                 {
                     chout <= "[MultiString] — new closest: " <= i <= ", distance " <= dist <= ", previous " <= _lastNotes[i] <= IO.nl();
                 }
             }
         }
             
         if (closest == -1)
         {
             cherr <= "Issue choosing string?" <= IO.nl();
             return -1;
         }
         return _stringChannels[strings[closest]];
     }
}