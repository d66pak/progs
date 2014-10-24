#!/bin/sh

LOGFILE=reg001.bf1.log
HOSTNAME=reg001.mail.bf1.yahoo.com

>$LOGFILE
yinst ssh -print-hostname -h $HOSTNAME "egrep \"dbaker19@sky.com|lisa-smith7@sky.com|paul.helme@sky.com|phil.hex@sky.com|r.behalrell@sky.com|savefc@sky.com\" /home/y/logs/reggate/all" > $LOGFILE
