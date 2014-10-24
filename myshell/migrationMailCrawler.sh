#!/bin/bash

if [ $UID != 0 ]
then
  echo "Must run as user root"
  exit 1
fi

PCOUNT=`/bin/ps -auxww | grep -i com.yahoo.mail.migration.crawler.[M]igrationIdxCrawler |wc -l`
echo "Number of Migration Process Running : " $PCOUNT
if [ $PCOUNT == 1 ]
 then
  echo "Exiting as there is already a MigrationScript running - try ps -auxww | grep -i com.yahoo.mail.migration.archive.[M]igrationIdxCrawler"
  echo "Exiting..."
  exit 1
fi

CLASSPATH=/home/y/lib/jars/MigrationArchiveMailMover.jar:/home/y/lib/jars/LightSaber.jar
LC_ALL=en_US.ISO8859-1 /home/y/libexec/java/bin/java -Xms128m -Xmx512m -d32 -Djava.library.path=/home/y/lib -cp $CLASSPATH com.yahoo.mail.migration.crawler.MigrationIdxCrawler $*
