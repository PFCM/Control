/***********************************************************************
   Code for Robot Network -- needs a cool name
   
   by Paul Mathews
   indebted to code by Ness Morris and Bruce Lott
   
   
   Victoria University Wellington, 
   School of Engineering and Computer Science
   
***********************************************************************
   File: Instrument.ck
   Desc: Base class for all instruments attached to the server,
         by itself does almost nothing
***********************************************************************/

public class Instrument {
    OscRecv oscIn; // assumed to be initialised and running
    
    
    
    // Public initialiser ensures we can init all instruments
    // from the outside.
    // Unsure what arguments this will require
    fun void init(OscRecv input, FileIO names) {
        cherr <= "Attempting to initialise base Instrument class directly. Not recommended" <= IO.nl(); 
    }
    
    // Private intialiser to be called from derived classes
    // because they can't call super version of overridden function
    // needs a list of messages 
    // will use the first point at which they diverge as a prefix for 
    // the standard interface
    fun void __init(OscRecv input, string names[]) {
        input @=> oscIn;
        // get messages from names
        // want to implement some form of inheritance in the osc 
        // address names as well, maybe keep hardcoded a list of 
        // messages in this class, or maybe keep a file
        // kicking around (could be nicer), or generate
        // them on the fly
        // Regardless we will have to send the list of available
        // messages and instruments to the client, bc it seems
        // unreasonable to keep files in two places
        // this will require some prior handshaking, 
        // the client app will have to send a startup message on 
        // on joining the network
        
    }
    
    // Returns the highest level of this Instruments address pattern
    fun string getPrefix() { 
        cherr <= "getPrefix() unimplemented" <= IO.nl();
        return null; 
    }
    
    // Deals with an OSC message
    // this class takes care of handling the OSC, 
    // subclasses need only override this method
    fun void handleMessage(OscEvent event) {}
}