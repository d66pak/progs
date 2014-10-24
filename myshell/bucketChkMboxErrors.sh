#!/bin/bash

# 1st param : checkMbox failure file

hn=`hostname`
NUM="${hn:3:3}"
NOUDB="f$NUM-no-udb-record.log"
SIDMISS="f$NUM-sid-udb-key-missing.log"
DISDEL="f$NUM-mbox-dis-n-del.log"
DIS="f$NUM-mbox-disabled.log"
DEL="f$NUM-mbox-deleted.log"
MBOXNF="f$NUM-mbox-not-exist.log"
#CNFARMS="f$NUM-on-cn-farms.log"
NONCNFARMS="f$NUM-on-non-cn-farms.log"
UNKNOWN="f$NUM-unknown-error.log"
SCPFILE="f$NUM-scp"
> $SCPFILE

grep -v "(1953)" $1 | grep "ERROR=No UDB record exists" > $NOUDB
grep -v "(1953)" $1 | grep "ERROR=SID udb key missing" > $SIDMISS
grep -v "(1953)" $1 | grep "ERROR=MBox is disabled & deleted" > $DISDEL
grep -v "(1953)" $1 | grep "ERROR=MBox disabled" > $DIS
grep -v "(1953)" $1 | grep "ERROR=MBox deleted" > $DEL
grep -v "(1953)" $1 | grep "ERROR=unknown error" > $UNKNOWN
grep -v "(1953)" $1 | grep "ERROR=Mbox does not exist on this farm" > $MBOXNF
#grep -v "(1953)" $1 | grep "Mbox not in this farm" | egrep "\(150\)|\(151\)|\(152\)|\(153\)|\(156\)|\(157\)|\(158\)|\(159\)|\(921\)|\(922\)|\(924\)" > $CNFARMS
grep -v "(1953)" $1 | grep "ERROR=Mbox not in this farm" | egrep -v "\(150\)|\(151\)|\(152\)|\(153\)|\(156\)|\(157\)|\(158\)|\(159\)|\(921\)|\(922\)|\(924\)" > $NONCNFARMS

echo "$NOUDB       : $(wc -l < $NOUDB)"
echo "$SIDMISS : $(wc -l < $SIDMISS)"
echo "$DISDEL      : $(wc -l < $DISDEL)"
echo "$DIS       : $(wc -l < $DIS)"
echo "$DEL        : $(wc -l < $DEL)"
echo "$MBOXNF      : $(wc -l < $MBOXNF)"
#echo "$CNFARMS        : $(wc -l < $CNFARMS)"
echo "$NONCNFARMS     : $(wc -l < $NONCNFARMS)"
echo "$UNKNOWN       : $(wc -l < $UNKNOWN)"
SUCCESS=$(egrep -c "but on farm \(1953\)" $1)
echo "successfully migrated to 1953:       $SUCCESS"

for farm in 150 151 152 153 156 157 158 159 921 922 924
do
  count=$(grep -v "(1953)" $1 | grep -c "but on farm ($farm)")
  if [ $count -gt 0 ]
  then
    filename="f$NUM-on-cn-farm-f$farm.log"
    grep -v "(1953)" $1 | grep "but on farm ($farm)" | cut -d= -f2 > $filename
    echo "$filename     : $(wc -l < $filename)"
    echo "rsync -az $filename web$farm""03.mail.cnb.yahoo.com:" >> $SCPFILE 
  fi
done

echo $SCPFILE
find . -type f -size 0 -exec rm {} +
