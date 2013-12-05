/***********************************************************************
   Code for Robot Network -- needs a cool name
   
   by Paul Mathews
   indebted to code by Ness Morris and Bruce Lott
   
   
   Victoria University Wellington, 
   School of Engineering and Computer Science
   
***********************************************************************
   File: Util.ck
   Desc: Helpful utilities to complement the standard library.
***********************************************************************/

public class Util
{
    /** splits the string by the given pattern (not regex)*/
    fun static string[] splitString( string in, string pattern )
    {
        string s[0];
        __split(in, pattern, s);
        return s;
    }
    
    /** private recursive call */
    fun static void __split( string in, string pat, string results[] )
    {
        // find the pattern
        in.find( pat ) => int where;
        
        if ( where >= 0 )
        {
            results.size( results.size()+1 );
            in.substring( 0,where ) => results[results.size()-1];
            return __split( in.substring(where + pat.length()), pat, results );
        }
        results.size( results.size()+1 );
        in => results[results.size()-1];
        return;
    }
    
    /** trims leading and trailing quotes (one of each only) */
    fun static string trimQuotes( string in )
    {
        // check if the back is quoted
        
        (in.charAt(in.length()-1) == '"') => int back; // hackery
        (in.charAt(0) == '"') => int front;
        return in.substring(front, in.length()-(front+back));
       
    }
    
    /** returns the default messages from a given name */
    fun static string[] makeDefaults( string name )
    {
        // check if it starts with a /
        name => string start; // copy first
        if ( !name.charAt(0) == '/' )
        {
            "/" + start => start;
        }
        string defaults[0];
        defaults<<start+"/note"; 
        defaults<<start+"/control";
        return defaults;
    }
}