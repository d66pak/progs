#!/bin/bash

hn=`hostname`
name="/tmp/${hn:0:10}txt"
egrep "Unable to acquire lock for|Ignoring part|Acquired lock for" $1 > $name
