#!/usr/bin/perl

use strict;
use warnings;

#my @array = qw(/home/y/bin/some.pl
#http://some.conf.cksum);
my $value = 'asdkfhldk';

my @array = ('/home/y/bin/some.pl',
'http://some.conf.cksum',
"$value/home/y");

print "No of elements: $#array\n";

for my $elem (@array) {
  print "$elem -- ";
}
print "\n";

my @parts = ('abc', , );

my $allparts = join("\0", @parts);

print "allparts: $allparts\n", " Length: ", length($allparts), "\n";


my @chars = split //,$allparts;

my @ascii = map(ord, @chars);
print "@ascii\n";

