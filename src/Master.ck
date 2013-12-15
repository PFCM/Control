Machine.add(me.dir()+"/Util.ck");
Machine.add(me.dir()+"/Instrument.ck");
Machine.add(me.dir()+"/MIDIInstrument.ck");
// Add all the instruments — recurse through subdirectories
// this just makes sure we can refer to unconnected instruments in code
// and still have it compile
FileIO instrDir;
if ( !instrDir.open( me.dir()+"/../Instruments", FileIO.READ ))
    cherr <= "Could not open" <= me.dir()+"/../Instruments" <= IO.nl();
else
{
    searchDir( instrDir, me.dir()+"/../Instruments" );
}

Machine.add(me.dir()+"/Server.ck");



// looks for .ck to add
fun void searchDir( FileIO dir, string path )
{
    chout <= "(Master) looking for files to add in: " <= path <= IO.nl();
    if ( !dir.isDir() )
        return;
    
    dir.dirList() @=> string files[];
    // go through each, add if .ck, recurse if dir
    for ( int i; i < files.cap(); i++ )
    {
        if ( RegEx.match( ".ck$", files[i] ) )
            Machine.add( path + "/" + files[i] );
        else
        {
            // open it
            FileIO fio;
            if ( !fio.open( path + "/" + files[i] ) )
                chout <= "Could not open " <= path <= "/" <= files[i] <= " —— skipping." <= IO.nl();
            else
            {
                if ( fio.isDir() )
                    searchDir( fio, path+"/"+files[i] );
            }
        }
    }
}