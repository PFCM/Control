OscSend osend;
osend.setHost("localhost", 50000);

1::second => now;
osend.startMsg("/*/note","ii");
osend.addInt(64); osend.addInt(64);
1::second => now;
osend.startMsg("/*/noteoff","ii");
osend.addInt(64); osend.addInt(64);