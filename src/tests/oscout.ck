OscSend osend;
osend.setHost("192.168.33.1", 50000);

1::second => now;
osend.startMsg("/ardu/note","ii");
osend.addInt(64); osend.addInt(64);
1::second => now;
osend.startMsg("/ardu/noteoff","ii");
osend.addInt(64); osend.addInt(64);