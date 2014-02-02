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
// use setAlgorithm() to choose how it gets done
public class MultiStringInstrument extends MidiInstrument
{
    // Variables
    int _numStrings;                 // how many strings we actually have
    int _stringMax[0];     // the maximum (highest) MIDI note number per string
    int _stringMin[0];     // the minimum (lowest) MIDI note number per string
    int _stringChannels[0]; // channel for each string
    int _lastNotes[0]; // i polyphonic mode this is a rank based on how recently they've played
    
    // Static fields to determine the algorithm used
    1 => static int CHOOSER_POLYPHONIC; // favours spreading the notes across the strings
    0 => static int CHOOSER_MONOPHONIC; // just chooses the nearest string (default)
    int _algorithm; // which one we're actually using
    // Static fields to determine the tie-breaking behaviour
    1 => static int BREAK_UP; // break towards higher range
    2 => static int BREAK_DOWN; // break towards lower range
    3 => static int BREAK_MID; // break by shortest distance to midpoint of range
    4 => static int BREAK_LOW; // break towards shortest distance to lowest note in range
    5 => static int BREAK_HIGH; // break by distance from highest note in range
    int _tiebreaker; //ccco
    
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
     
     fun void setChannels( int chans[] )
     {
         for (int i; i < _numStrings; i++)
             chans[i] => _stringChannels[i];
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
     
     // sets the algorithm to use
     fun void setAlgorithm(int algo)
     {
         algo => _algorithm;
     }
     // sets the tuberculosis
     fun void setTiebreaker(int tb)
     {
         tb => _tiebreaker;
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
         
         // if there are more than one use the algorithm
         if (strings.cap() == 1)
         {
             note => _lastNotes[strings[0]];
             return _stringChannels[strings[0]];
         }
         if (strings.cap() == 0)
         {
             // fail silently unless debugging turned on
             if (debug)
                 chout <= "[MultiString] No possible strings for note: " <= note <= IO.nl();
             return -1;
         }
         if ( _algorithm == CHOOSER_MONOPHONIC )
             return __getMonophonicString(note, strings);
         if ( _algorithm == CHOOSER_POLYPHONIC )
             return __getPolyphonicString(note, strings);
     }
    
     
     
     // chooses the string currently nearest to the note
     fun int __getMonophonicString(int note, int strings[])
     {
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
                 strings[i] => closest;
             }
             else if (temp == dist)
             {
                 // tie
                 // resolve tie
                 _breakTie(closest, i, note) => closest;
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
     
     // tries not to use the strings that hve most recently been used
     fun int __getPolyphonicString(int note, int strings[])
     {
         // get this string in strings with the highest rank (in _lastnotes)
         -1 => int highest;
         -1 => int highestString;
         for (int i; i < strings.cap(); i++)
         {
             if (_lastNotes[strings[i]] > highest)
             {
                 strings[i] => highestString;
                 _lastNotes[strings[i]] => highest;
             }
             else if (_lastNotes[strings[i]] == highest) // break tie
             {
                 _breakTie(strings[i], highestString, note) => int winner;
                 // highest stays the same
                 winner => highestString;
             }
         }
         
         
         // now we have the highest
         if (highest == -1)
         {
             cherr <= "[MultiString] Issue choosing string in polyphonic mode —— no rankings?" <= IO.nl();
             return -1;
         }
         
         if (debug)
             chout <= "[OneChannelSwivel] Chosen string " <= highestString <= " with ranking " <= highest <= IO.nl();
         
         // now we set the chosen string to the lowest priority and increment the rest of the strings that were possible
         0 => _lastNotes[highestString];
         for (int i; i < strings.cap(); i++)
         {
             if (strings[i] != highestString)
                 _lastNotes[strings[i]]++;
         }
         
         return _stringChannels[highestString];
     }
     
     // breaks a tie, takes two string numbers (indices) and a note and returns the best one
     // according to the current tie breaking behaviour
     fun int _breakTie( int a, int b, int note )
     {
         // Dear ChucK, for Christmas I would like switch/case. Regards, Paul.
         if (_tiebreaker == 0)
         {
             return a;
         }
         else if (_tiebreaker == BREAK_UP) // returns range with highest mid
         {
             if (_getMid(a) > _getMid(b)) // if equal, we return b. This is clearly optimal behaviour
                 return a;
             return b;
         }
         else if (_tiebreaker == BREAK_DOWN) // returns range with lowest mid
         {
             if (_getMid(a) <= _getMid(b)) // opposite of above
                 return a;
             return b;
         }
         // this is probably one of the most useful
         else if (_tiebreaker == BREAK_MID) // returns range with mid closest to note
         {
             if ( Math.abs(_getMid(a)-note) < Math.abs(_getMid(b)-note) )
                 return a;
             return b;
         }
         else if (_tiebreaker == BREAK_LOW) // return range with lowest note nearest note
         {
             if ( Math.abs(_stringMin[a]-note) < Math.abs(_stringMin[b]-note) )
                 return a;
             return b;
         }
         else if (_tiebreaker == BREAK_HIGH) // return range with highest note nearest note
         {
             if ( Math.abs(_stringMax[a]-note) < Math.abs(_stringMax[b]-note) )
                 return a;
             return b;
         }
         cherr <= "[MultiStringInstrument] Unknown tie breaker: " <= _tiebreaker <= IO.nl();
     }
     
     // returns the midpoint of the range for a given string
     // note returns int
     fun int _getMid( int str )
     {
         return ((_stringMax[str] + _stringMin[str])/2);
     }
}