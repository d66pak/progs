#!/usr/bin/perl

use strict;
use warnings;

if (open(my $fh, "<MF_CFG_VERSION")) {
  my $line;
  while ($line = <$fh>) {
      if ($line =~ /v(\d+(.\d+)+)\s+/) {
        print $1, "\n";
        last;
    }
  }
}
else {
  die "cannot open file";
}

my $v1 = "1.1.1";
my $v2 = "1.1.1";

print "v1 = $v1 v2 = $v2\n";

if ($v1 gt $v2) {

  print "v1 > v2\n";
}
elsif ($v1 lt $v2) {

  print "v1 < v2\n";
}
elsif ($v1 eq $v2) {

  print "v1 == v2\n";
}

my $command = "/home/y/bin/parse_version $v1 $v2";
my $result = qx/$command/;
print ("parse_version : $result");

if ($result =~ /</) {

  print ("v1 is less than v2\n");
}
elsif ($result =~ /==/) {

  print ("v1 is equal to v2\n");
}
