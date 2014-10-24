#!/bin/bash

CLASSPATH=/home/y/lib/jars/yjava_ycore.jar:/home/dtelkar/deepak/progs/myjava/jersy-client/simple_jersey_client/target/simple_jersey_client-1.0-SNAPSHOT.jar
LC_ALL=en_US.ISO8859-1 /home/y/bin/java -Xms128m -Xmx512m  -Djava.library.path=/home/y/lib -cp $CLASSPATH learn.deepak.java.App $*
