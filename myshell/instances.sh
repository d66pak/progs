#!/usr/local/bin/sh

PCOUNT=`ps auxww | grep -i [G]calctool | wc -l`
echo "Number of instances: "$PCOUNT;

if [ $PCOUNT -gt 2 ]
then
  echo "More than two instances";
elif [ $PCOUNT -ge 1 ]
then
  echo "More than or equal to one instance";
else
  echo "Zero instances runnint";
fi

