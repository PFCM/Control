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
         for ( startChan => int i; i > 0; i-- ) 
         {
             i => _stringChannels[i];
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
             // assume strings start at their lowest note
             min[i] => _lastNotes[i];
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
         if (strings.cap() == 1)
         {
             note => _lastNotes[strings[0]];
             return _stringChannels[strings[0]];
         }
         
         256 => int dist;
         -1 => int closest;
         for ( int i; i < strings.cap(); i++ )
         {
             Math.abs(_lastNotes[strings[i]] - note) => int temp;
             if (debug) 
             {
                 chout <= "[MultString] String " <= strings[i] <= " distance " <= temp <= IO.nl();
             }
             if ( temp < dist )
             {
                 temp => dist;
                 i => closest;
             }
             else if (temp == dist)
             {
                 // tie
                 // compare distance of desired note from centre of range
                 strings[i] => int a;
                 strings[closest] => int b;
                 
                 
                 if (debug)
                     chout <= "[MultiString] resolving tie between " <= a <= " and " <= b <= IO.nl();
                 
                 
                 // get midpoint of a range
                 (0.5 * (_stringMin[a] + _stringMax[a]))$int => int amid;
                 // midpoint of b range
                 (0.5 * (_stringMin[b] + _stringMax[b]))$int => int bmid;
                 
                 if (debug)
                 {
                     chout <= "[MultiString] \t" <= a <= " midpoint: " <= amid <= ", distance: " <= Math.abs(amid-note) <= IO.nl();
                     chout <= "[MultiString] \t" <= b <= " midpoint: " <= bmid <= ", distance: " <= Math.abs(bmid-note) <= IO.nl();
                 }
                 
                 // if a wins it is the new closest, otherwise the old closest remains
                 if ( Math.abs(amid-note) < Math.abs(bmid-note) )
                 {
                     
                     i => closest;
                     temp => dist;
                 }
             }
         }
             
         if (closest == -1)
         {
             cherr <= "Issue choosing string?" <= IO.nl();
             return -1;
         }
         
         if (debug)
             chout <= "[MultiString] Chosen string " <= strings[closest] <= IO.nl();
         
         note => _lastNotes[strings[closest]];
         return _stringChannels[strings[closest]];
     }
}