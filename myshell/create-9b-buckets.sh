#!/bin/bash

# 1 - yid host file
# 2 - dir to create op
# 3 - unique farm file

YIDHOSTFILE=$1
DIR=$2

if [ -z "$3" ]
then
  UNIQFARMS_FILE="$DIR/uniq.farms"
  sort -k2 $YIDHOSTFILE | awk '{print $2}' | uniq > $UNIQFARMS_FILE
else
  UNIQFARMS_FILE="$3"
fi

echo "$(wc -l < $UNIQFARMS_FILE) unique hosts!"

while read host
do
  FNAME="$DIR-$host.yids"
  grep $host $YIDHOSTFILE | awk '{print $1}' > $DIR/$FNAME
  echo "rsync -az $FNAME ../checkMboxParallel.pl ../ForkManager.pm $host:" >> $DIR/scp-bucket-files
  echo "yinst ssh -print-hostname -continue_on_error -h $host \"date\"" >> $DIR/run-sshtest-cmd
  echo "yinst ssh -print-hostname -continue_on_error -remote_timeout 5000 -h $host \"sudo ./checkMboxParallel.pl -f $FNAME --unlock\"" >> $DIR/run-chkmbox-cmd
  echo "yinst ssh -print-hostname -continue_on_error -h $host \"sudo -u nobody2 /home/y/bin/ymail_migration_client --ignore_peak --server_host web19530$((RANDOM%6+1)).mail.sg3.yahoo.com --list $FNAME --job_name $DIR-$host\"" >> $DIR/run-fluid-mig-cmd
#  echo "yinst ssh -print-hostname -continue_on_error -h $host \"sudo -u nobody2 /home/y/bin/ymail_migration_client --ignore_peak --server_host web195303.mail.sg3.yahoo.com --list $FNAME --job_name $DIR-$host\"" >> $DIR/run-fluid-mig-cmd
  echo "rsync -az
  $host:/rocket/ms1/ymail_migration_client/migration_log-$host-$(date +%F) ." >> $DIR/get-fluid-logs
done < $UNIQFARMS_FILE

