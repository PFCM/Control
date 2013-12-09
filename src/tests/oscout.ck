OscSend osend;
osend.setHost("192.168.33.2", 50001);

1::second => now;
osend.startMsg("/instruments/add","s");
osend.addString("END");