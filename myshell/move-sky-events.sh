#!/bin/sh

#LOGFILE=move.log
HOSTFILE=mail-retry-hosts
SRCQ=retry
DESTQ=priority
TRANSFORM=MailRetryToResync
COUNT=100
FILE=mail-retry-users-0702.txt

#> $LOGFILE


yinst ssh -print-hostname -continue_on_error -Hostfile $HOSTFILE "sudo ./migman qfix -s $SRCQ -d $DESTQ -t $TRANSFORM -f $FILE"

