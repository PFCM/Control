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

Instrument @ instruments[10]; // array of references, initialises to null rather than default objects

// Global OSC receiver, just needs to listen
OscRecv netRecv;
// grab a port outside the registered range
// port is now 50000
50000 => netRecv.port;


for (int i; i < 10; i++) {
    if (maybe) {
        MidiInstrument m;
        m.setMidiPort(0);
    }
    else
        new Instrument @=> instruments[i];
}

for (int i; i < instruments.cap(); i++)
    instruments[i].init();