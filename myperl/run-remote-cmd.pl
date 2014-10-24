#!/home/y/bin/perl

use strict;
use warnings;
use Term::ReadPassword;
use ExecRemoteCmd;

my $CMD = 'find /rocket/ms1/external/accessMail/sky_mig/low-priority/ -type f | wc -l';

my $HOSTFILE = "sky-hosts";
my $time = time();
my $LOGFILE = "rc-" . $time;

my $passwd = read_password('ssh password: ');

open (my $logfile, ">", $LOGFILE) or die "Error opening $LOGFILE: $!";
open (my $hf, "<", $HOSTFILE) or die "Error opening $HOSTFILE: $!";

print "CMD: $CMD\n";

while (my $host = <$hf>) {

  chomp($host);
  print "Running command on:\t$host\n";

  my $runCmd = ExecRemoteCmd->new(
    user => 'dtelkar',
    password => $passwd,
    host => $host,
    logfilehandle => $logfile
  );

  my $op = $runCmd->runCommand($CMD);
}

close ($logfile);
close ($hf);

print "log file: $LOGFILE\n";
