#!/bin/sh

#LOGFILE=yinstssh.log
HOSTFILE=sky-hosts
#CMD=$(echo "sudo cp migman.conf ~root/migman.conf")
#CMD=$(echo "find /rocket/ms1/external/accessMail/sky_mig/low-priority/ -type f | wc -l")

#> $LOGFILE


#yinst ssh -print-hostname -continue_on_error -Hostfile $HOSTFILE "find /rocket/ms1/external/accessMail/sky_mig/retry/ -type f | wc -l"
yinst ssh -print-hostname -continue_on_error -Hostfile $HOSTFILE "sudo ./analyze-events.pl -q new --printuser --listevent --checkguid --checksid --checksilo --listmodule --verbose"

