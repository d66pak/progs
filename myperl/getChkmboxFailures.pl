#! /home/y/bin/perl

use strict;
use warnings;

############# MAIN ##############
my $host      = undef;
my $errorFile = undef;

while ( my $line = <> ) {

 chomp($line);

 if ( $line =~ m/(web.*?\.yahoo\.com:)/ ) {

  $host = $1;
 } elsif ( $line =~ m/checkMbox-fail-/ ) {
  
  $line =~ s/\r//;
  $errorFile = $line;
 }

 if ( defined $host && defined $errorFile ) {

  $host =~ m/(web\d+)/;
   
  my $cmdStr = "rsync -az $host$errorFile $1-checkMbox-fail.log";
  
  print "$cmdStr\n";
  $host = undef;
  $errorFile = undef;
 }
}
