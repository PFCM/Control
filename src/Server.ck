/***********************************************************************
   Code for Robot Network -- needs a cool name
   
   by Paul Mathews
   indebted to code by Ness Morris and Bruce Lott
   
   
   Victoria University Wellington, 
   School of Engineering and Computer Science
   
***********************************************************************
   File: Server.ck
   Desc: contains the loop for the server; populates a list of 
         instruments and sets them up receiving OSC and sending
         whatever they send.
***********************************************************************/

Instrument @ instruments[0]; // array of references, initialises to null rather than default objects

// Global OSC receiver, just needs to listen
OscRecv netRecv;
// grab a port outside the registered range
// port is now 50000
50000 => netRecv.port;


// Get all the files, this will tell us what robots to load
FileIO dir;
if ( !dir.open( me.dir() + "/../Instruments", FileIO.READ ) )
    cherr <= "Could not open '" <= me.dir()+"/../Instruments" <= "' no files loaded." <= IO.nl();
else
{
    dir.dirList() @=> string files[];
    chout <= "Loading files" <= IO.nl();
    // load the files, add an instrument each
    for ( int i; i < files.cap(); i++ )
    {
        chout <= "File: " <= files[i] <= IO.nl();
        FileIO inst;
        if ( !inst.open( me.dir() + "/../Instruments/" + files[i], FileIO.READ ) )
            cherr <= "Error opening '" <= me.dir() + "/../Instruments/" <= "', ignoring." <= IO.nl();
        else
        {
            // TODO make this better, regex might be nice but it doesn't give us the index of a match
            inst.readLine() => string output;
            if (output.substring(0,5) != "type=")
                cherr <= "\t" <= "File must begin with 'type='" <= IO.nl();
            else
            {
                output.substring(5) => string type;
                null @=> Instrument @ newI; // reference to instrument, no need to construct because we will jam a subclass in here
                // HERE IS WHERE WE CHECK FOR KNOWN TYPES OF INSTRUMENT
                // CURRENTLY KNOWN
                // MIDI (MIDIInstrument.ck) -- a generic MIDI instrument
                if (type == "MIDI")
                {
                    new MidiInstrument @=> newI; // put a MIDI instrument into it
                    /*TEMP
                    m.setMidiPort(0);
                    m @=> newI;*/
                }
                else
                {
                    cherr <= "\t" <= "Unkown output type '" <= type <= "'" <= IO.nl();
                    break;
                }
                
                
                newI.init(netRecv, inst); // initialise with the OSC recv and the rest of the file
                // put it in the list
                instruments.size(instruments.size()+1);
                newI @=> instruments[instruments.size()-1];
            }
        }
    }
}

netRecv.listen(); // now we want to hear

// loop
while ( true ) 1::second => now;