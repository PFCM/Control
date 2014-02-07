/***********************************************************************
   Code for Robot Network -- needs a cool name
   
   by Paul Mathews
   indebted to code by Ness Morris and Bruce Lott
   
   
   Victoria University Wellington, 
   School of Engineering and Computer Science
   
***********************************************************************
   File: Instrument.ck
   Desc: Base class for all instruments attached to the server,
         by itself does almost nothing, just sets up OSC listening
***********************************************************************/

public class Instrument {
    OscRecv oscIn; // assumed to be initialised and listening on the correct port
    string name;   // some kind of identification
    string patterns[0]; // to store the current address patterns for later queries
    string notes[0];
    0::samp => dur delay;
    true => int do_delay;
    
    // Public initialiser ensures we can init all instruments
    // from the outside.
    // Unsure what arguments this will require
    fun int init(OscRecv input, FileIO names) {
        cherr <= "Attempting to initialise base Instrument class directly. Not recommended" <= IO.nl(); 
    }
    
    // Private intialiser to be called from derived classes
    // because they can't call super version of overridden function
    // needs a list of messages 
    // will use the first point at which they diverge as a prefix for 
    // the standard interface
    // returns non 0 on success, 0 on failure (ie boolean)
    fun int __init(OscRecv input, string names[]) {
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
        
        
        // for now 
        names @=> patterns;
        // need to check if the defaults are specified
        int note, control;
        for ( int i; i < patterns.cap(); i++ )
        {
            spork~__listener( oscIn.event( patterns[i] ), patterns[i] );
            if (!note)
                RegEx.match( "/note,[ ]*ii$", patterns[i] ) => note;
            if (!control)
                RegEx.match( "/control,[ ]*ii$", patterns[i] ) => control;
            
        }
        if ( !note )
        {
            chout <= "Adding default note listener for " <= name <= IO.nl();
            "/" + name + "/note,ii" => string notes;
            spork~__listener( oscIn.event( notes ), notes ); 
        }
        if ( !control )
        {
            chout <= "Adding default control listener for " <= name <= IO.nl();
            "/" + name + "/control,ii" => string controls;
            spork~__listener( oscIn.event( controls ), controls ); 
        }
        
        return 1;
    }
    
    // slightly less private init method, can be overridden by abstract classes further down the line for when they need to insert additional init
    fun int _init(OscRecv input, string names[])
    {
        return __init(input,names);
    }
    
    // Private method to set the name
    fun void __setName(string n)
    {
        n => name;
    }
    
    // Sets the delay applied prior to handling new notes. This is used as part of the servers
    // latency compensation.
    fun void setDelay(dur newDelay)
    {
        newDelay => delay;
    }
    
    // Returns the highest level of this Instruments address pattern
    fun string getPrefix() { 
        cherr <= "getPrefix() unimplemented" <= IO.nl();
        return null; 
    }
    
    // Deals with an OSC message
    // this class takes care of handling the OSC, 
    // subclasses need only override this method
    // needs a copy of the string that created the event
    // because there is no way of getting an address pattern
    // from an OscEvent
    fun void handleMessage(OscEvent event, string addrpat) {}
    
    // listens to a specific OscEvent, calls the handle message function when the event fires
    fun void __listener( OscEvent event, string addrpat )
    {
        chout <= name <=  " now listening for: " <= addrpat <= IO.nl();
        
        // hold on to these (was getting some odd crashes)
        event @=> OscEvent @ evt;
        addrpat => string pat;
        
        // will exit when parent exits
        while ( evt => now )
        {
            while ( evt.nextMsg() )
            {
                if (do_delay)
                    spork~__delayAndHandle( evt, pat );
                else
                    handleMessage( evt, pat );
            }
        }
    }
    
    fun void __delayAndHandle( OscEvent evt, string pat )
    {
        delay => now;
        handleMessage( evt, pat );
    }
    
    // Sends the non-default methods
    // subclasses are better qualified to deal with this, as 
    // it is necessary to send info about what should
    // messages the client needs to receive
    fun void sendMethods( OscSend s )
    {  }
    
    // sends any notes that might have been in the file
    fun void sendNotes( OscSend s ) {}
}