#!/home/y/bin/perl

use strict;
use warnings;
use utf8;

open(my $fh, "<", $ARGV[0]) or die "Error opening $ARGV[0]: $!";

my $data = <$fh>;

if ($data =~ /([^[:ascii:]])/) {
  print "Non ascii found: $1\n";
}

