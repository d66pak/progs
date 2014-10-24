#!/usr/bin/perl

use strict;
use warnings;

my $command1 = "yinst set dist_tools.BINDIR";
my $command2 = "yinst set pkgname.var";

my $ret = qx/$command2 2>&1/;

if ($?) {
  print "Error: $? $ret\n";
  if ($ret =~ /Variable is not set:/) {
    print "This is a new variable\n";
  }
}
else {
  print "Return status: $ret\n";
}


my $ret1 = qx/$command1 2>&1/;

if ($?) {
  print "Error: $?\n";
}
else {
  print "Return status: $ret1\n";
  my @val = split /\s+/, $ret1;
  print "Package.variable: $val[0]\n";
  print "value: $val[1]\n";
}

if ("abc" == "abc") {
  print "EQUAL STR\n";
}

if (1 eq 1) {
  print "EQUAL VAL\n";
}
