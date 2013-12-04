OscSend osend;
osend.setHost("localhost", 50000);

1::second => now;
osend.startMsg("/test/a","i");
osend.addInt(2);