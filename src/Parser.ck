/***********************************************************************
Code for Robot Network -- needs a cool name

by Paul Mathews
indebted to code by Ness Morris and Bruce Lott


Victoria University Wellington, 
School of Engineering and Computer Science

***********************************************************************
File: Parser.ck
Desc: Contains static methods to parse bits of files, probably 
eventually methods to parse whole files.
***********************************************************************/

public class Parser 
{
    /** Static fields for caching so that we don't have to do the nastier string operations
        too often. Adds a slight overhead to some methods to check but on the whole should
        help a little bit. */
    static string __lastLine; // the last line parsed
    static string[] __splitLastLine; // the cached split line
    
    
    
    /** Returns a name, if the string is "name=something" this will return 
        "something". Ignores comments. */
    fun static string parseName( string line )
    {
        line => Util.stripComments => string name;
        if ( name == "" ) return name;
        if ( line.substring( 0,5 ) != "name=" )
        {
            cherr <= "Expecting: name=something, got " <= line <= IO.nl();
            return "";
        }
        return line.substring(5).trim();
    }
    
    /** Parses a note field from a text file, returns the note if successful otherwise empty string */
    fun static string parseNote( string note )
    {
        Util.stripComments( note ) => string line;
        if ( line.find("note=") != 0 )
            return "";
        return line.substring(5);
    }
    
    /** Determines whether or not the given line is a note */
    fun static int isNote( string line )
    {
        return (line.find("note=")!=-1);
    }
    
    /** Returns true if the line is a translation or note. It would
        be wise to check whether it is a note first, this method only 
        checks to see whether the line contains an OSC message, a note 
        containing an OSC message would return true */
    fun static int isTranslation( string in )
    {
        return ( Regex.match( "\"(/[a-zA-Z0-9]+)+,[if]+\"", line ))
    }
    
    /** Gets the port number (as an int) out of a port description line */
    fun static int parseMidiPortNumber( string in )
    {
        in => Util.stripComments => string line;
        Util.splitString(line, "=") @=> string s[];
        
        if (s.cap() < 2 || s[0] != "port")
        {
            cherr <= "Error parsing MIDI instrument file: expected port=number got " <= line <= IO.nl();
            return -1;
        }
        return s[1].toInt();
    }
    
    /** Gets the port number as a string for ports that are a name */
    fun static string parseMidiPortString( string in )
    {
        in => Util.stripComments => string line;
        Util.splitString(line, "=") @=> string s[];
        
        if (s.cap() < 2 || s[0] != "port")
        {
            cherr <= "Error parsing MIDI instrument file: expected port=number got " <= line <= IO.nl();
            return -1;
        }
        return s[1];
    }
    
    /** Determines whether a line is a midi port description */
    fun static int isMidiPort( string in )
    {
        return in.trim().find("port=") == 0;
    }
    
    /** determines whether a port description is a number or not */
    fun static int isMidPortNumber( string in )
    {
        return Regex.match( "^port=[0-9]+", in.trim() );
    }
    
    /** determines whether a line is a port description or not */
    fun static in isMidiPort( string in )
    {
        return Regex.match( "^port=", in.trim() );
    }
    
    /** Returns a status byte if one was specified in the translation, otherwise returns -1 */
    fun static int getMidiTranslationStatusByte( string in )
    {
        if (in != __lastLine)
        {
            in => __lastLine;
            Util.splitString(in, "=") => __splitLastLine;
        }
        
        if (__splitLastLine.cap() < 3)
        {
            return -1;
        }
        return __splitLastLine[0].toInt();
    }
    
    /** Returns an OSC address pattern if one was specified in the translation, otherwise warns and returns empty string */
    fun static string getMidiTranslationOscMessage( string in )
    {
        // have we alreaedy split the string
        if (in != __lastLine)

        {
 // write a function for this already!!!
            in => __lastLine;
            Util.splitString(in, "=") => __splitLastLine;
        }
        
        string pattern;
        
        if (__splitLastLine.cap() == 3)
        {
            __splitLastLine[1] => pattern;
        } 
        else if (__splitLastLine.cap() == 2)
        {
            __splitLastLine[0] => pattern;
        }
        else 
        {
            cherr <= "Error parsing MIDI file: expeciting translation, got " <= __lastLine <= IO.nl();
            return "";
        }
        
        if ( Util.isOscMsg(Util.trimQuotes(pattern)) )
        {
            cherr <= "Error parsing MIDI file: failed getting OSC message from " <= __lastLine <= IO.nl();
            return "";
        }
        
        return pattern;
    }
}