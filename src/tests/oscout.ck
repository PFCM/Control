OscSend osend;
osend.setHost("192.168.33.2", 50000);

1::second => now;
osend.startMsg("/MechBassString1/note","ii");
osend.addInt(2);
osend.addInt(3);