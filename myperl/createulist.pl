#!/usr/bin/perl
#---------------------#
#  PROGRAM:  argv.pl  #
#---------------------#
open(MYFILE, '>',$ARGV[0] ) or die $!;
$numArgs = $#ARGV + 1;

foreach $argnum (1 .. $#ARGV) {


#   print "$ARGV[$argnum]\n";

$event=$ARGV[$argnum];
#my $save=`udb-test -Rk mbr_guid $event`;
my $save=`udb-test -Rk mbr_guid $event`;
my @str = split(//, $save);
print MYFILE "$event $str[2]" ;
}

