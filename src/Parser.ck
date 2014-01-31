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
    /** Static reference to a class that holds info. Have to do it this way because ChucK and static data gets a bit weird.
        For some reason it refuses to allow static strings claiming they aren't a primitive type (and so only a static reference
        works at the moment) but it also does not let you make a reference to a string, claiming they are a primitive type. */
    static LineInfo @ __lastLine;
    false => static int __lastLineInit;
    
    
    /** Returns a name, if the string is "name=something" this will return 
        "something". Ignores comments. */
    fun static string parseName( string line )
    {
        line => Util.stripComments => string name;
        if ( name == "" || name.substring( 0,5 ) != "name=" )
        {
            cherr <= "Expecting: name=something, got " <= line <= IO.nl();
            return "";
        }
        return name.substring(5);
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
        containing an OSC message would return true. Need to make quotes optional */
    fun static int isTranslation( string in )
    {
        return ( RegEx.match( "^([12][2-9][0-9]=)?(\")?(/[a-zA-Z0-9]+)+,[ \t]*[ifs]+(\")?=[0-9]{3},([0-9]{2,3}|\\$[1-2]),([0-9]{2,3}|\\$[1-2])$", in ));
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
            return "";
        }
        return s[1];
    }
    
    /** Determines whether a line is a midi port description */
    fun static int isMidiPort( string in )
    {
        return in.trim().find("port=") == 0;
    }
    
    /** determines whether a port description is a number or not */
    fun static int isMidiPortNumber( string in )
    {
        return RegEx.match( "^port=[0-9]+", in.trim() );
    }
    
    /** determines whether a line is a port description or not */
    fun static int isMidiPort( string in )
    {
        return RegEx.match( "^port=", in.trim() );
    }
    
    /** Checks whether the line has been cahced or not */
    fun static void __checkCache( string in )
    {
        if (__lastLineInit == false)
        {
            new LineInfo @=> __lastLine;
            true => __lastLineInit;
        }
        
        if (in != __lastLine.line)
        {
            in => __lastLine.line;
            Util.splitString(in, "=") @=> __lastLine.splitLine;
        }
    }
    
    /** Returns a status byte if one was specified in the translation, otherwise returns -1 */
    fun static int getMidiTranslationStatusByte( string in )
    {
        __checkCache(in);
        
        if (__lastLine.splitLine.cap() < 3)
        {
            return -1;
        }
        return __lastLine.splitLine[0].toInt();
    }
    
    /** Returns an OSC address pattern if one was specified in the translation, otherwise warns and returns empty string */
    fun static string getMidiTranslationOscMessage( string in )
    {
        
        __checkCache(in);
        
        string pattern;
        
        if (__lastLine.splitLine.cap() == 3)
        {
            __lastLine.splitLine[1] => pattern;
        } 
        else if (__lastLine.splitLine.cap() == 2)
        {
            __lastLine.splitLine[0] => pattern;
        }
        else 
        {
            cherr <= "Error parsing MIDI file: expecting translation, got " <= __lastLine.line <= IO.nl();
            return "";
        }
        
        pattern => Util.trimQuotes => pattern;
        
        if ( !Util.isOscMsg(pattern) )
        {
            cherr <= "Error parsing MIDI file: failed getting OSC message from " <= __lastLine.line <= IO.nl();
            return "";
        }
        
        return pattern;
    }
    
    /** Checks a translation line is in fact a translation line and splits it into its components */
    fun static string[] parseTranslationLine( string in )
    {
        __checkCache(Util.stripComments(in));
       
       if (!isTranslation(__lastLine.line))
       {
           cherr <= "Expecting translation line, got " <= __lastLine.line <= IO.nl();
           return null;
       }
       
       return __lastLine.splitLine;
    }
}

private class LineInfo
{
    string line;
    string splitLine[0];
}