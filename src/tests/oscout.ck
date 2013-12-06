OscSend osend;
osend.setHost("localhost", 50000);

1::second => now;
osend.startMsg("/test/banana","ii");
osend.addInt(2);
osend.addInt(3);