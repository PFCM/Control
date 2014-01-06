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
        
    }
}