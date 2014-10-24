#!/bin/bash

if [ $UID != 0 ]
then
  echo "Must run as user root"
  exit 1
fi

PCOUNT=`/bin/ps -auxww | grep -i com.yahoo.mail.migration.archive.[M]igrationMailArchiver | wc -l`
echo "Number of Migration Process Running : " $PCOUNT
if [ $PCOUNT -ge 1 ]
 then
  echo "Exiting as there is already a MigrationScript running - try ps -auxww | grep -i com.yahoo.mail.migration.archive.[M]igrationMailArchiver"
  echo "Exiting..."
  exit 1
fi

CLASSPATH=MigrationArchiveMailMover.jar
LC_ALL=en_US.ISO8859-1 /usr/local/bin/java -Xms128m -Xmx256m  -Djava.library.path=/home/y/lib -cp $CLASSPATH com.yahoo.mail.migration.archive.MigrationMailArchiver $*
