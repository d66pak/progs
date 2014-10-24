#!/bin/bash
# ./checkUniqueAcquireLock.sh <files-having-sids>

TMPFILE=/tmp/zz12$$

grep 'Acquired lock for' web1953*.txt > $TMPFILE

while read sid
do
  locks=$(grep -c $sid $TMPFILE)
  if [ $locks -gt 1 ]
  then
    echo "ERROR: $sid"
    echo $(grep $sid $TMPFILE)
    echo "-------------------------"
  #else
    #echo "Unique lock for $sid"
  fi
done < $1
