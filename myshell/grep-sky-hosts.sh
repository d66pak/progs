#!/bin/sh

yinst ssh -print-hostname -continue_on_error -Hostfile sky-host-list "grep \"Elapsed time (milliseconds)\" /home/y/logs/yapache/us/error"
