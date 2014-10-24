#!/usr/bin/perl
# reg_exp.pl

use warnings;
use strict;

my $txt = "abcde aaaa bbbb cc jjjj dddd aaa";

while ($txt =~ /((?<char>\w)(\k<char>+))/g) {
  print "Word is: $1 \n";
}

