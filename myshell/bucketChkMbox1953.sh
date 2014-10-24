#!/bin/bash

# 1st param : checkMbox failure file
# 2nd param : prefix for output file names (optional)
#             If not given then current farm number will be prefixed

hn=`hostname`
NUM="${hn:3:4}"
if [ -z "$2" ]
then
  PRE="f$NUM"
else
  PRE="$2"
fi
NOUDB="$PRE-no-udb-record.log"
SIDMISS="$PRE-sid-udb-key-missing.log"
DISDEL="$PRE-mbox-dis-n-del.log"
DIS="$PRE-mbox-disabled.log"
DEL="$PRE-mbox-deleted.log"
MBOXNF="$PRE-mbox-not-exist.log"
#CNFARMS="$PRE-on-cn-farms.log"
NOTON1953="$PRE-not-on-1953.log"
SILOMISSING="$PRE-silo-udb-key-missing.log"
WRONGSILOKEY="$PRE-wrong-silo-key.log"
UNKNOWN="$PRE-unknown-error.log"

grep "ERROR=No UDB record exists" $1 > $NOUDB
grep "ERROR=SID udb key missing" $1 > $SIDMISS
grep "ERROR=MBox is disabled & deleted" $1 > $DISDEL
grep "ERROR=MBox disabled" $1 > $DIS
grep "ERROR=MBox deleted" $1 > $DEL
grep "ERROR=unknown error" $1 > $UNKNOWN
grep "ERROR=Mbox does not exist on this farm" $1 > $MBOXNF
grep "ERROR=Mbox not in this farm" $1 > $NOTON1953
grep "ERROR=SILO udb key missing" $1 > $SILOMISSING
grep "ERROR=Wrong SILO udb key" $1 > $WRONGSILOKEY

printf "%-60s : %d\n" "$NOUDB" "$(wc -l < $NOUDB)"
printf "%-60s : %d\n" "$SIDMISS" "$(wc -l < $SIDMISS)"
printf "%-60s : %d\n" "$SILOMISSING" "$(wc -l < $SILOMISSING)"
printf "%-60s : %d\n" "$WRONGSILOKEY" "$(wc -l < $WRONGSILOKEY)"
printf "%-60s : %d\n" "$DISDEL" "$(wc -l < $DISDEL)"
printf "%-60s : %d\n" "$DIS" "$(wc -l < $DIS)"
printf "%-60s : %d\n" "$DEL" "$(wc -l < $DEL)"
printf "%-60s : %d\n" "$MBOXNF" "$(wc -l < $MBOXNF)"
#printf "$CNFARMS          : $(wc -l < $CNFARMS)"
printf "%-60s : %d\n" "$NOTON1953" "$(wc -l < $NOTON1953)"
printf "%-60s : %d\n" "$UNKNOWN" "$(wc -l < $UNKNOWN)"

find . -type f -size 0 -exec rm {} +
