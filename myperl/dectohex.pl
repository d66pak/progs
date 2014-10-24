#!/usr/bin/perl

use strict;
use warnings;
use Math::BigInt;

my $num = 1421600626570616650;

#my $hex = sprintf("%x", $num);

#print "$hex\n";


my $string = "1421600626570616650";

#$string =~ s/(.)/sprintf("%x",ord($1))/eg;

print "$string\n";

my $str = '123';
#print "hex -- " . hex($str) . "\n";

my $hexnum = Math::BigInt->new("1421600626570616650")->as_hex;
print "$hexnum\n";

$hexnum =~ s/^0x/GmailId/;
print "$hexnum\n";

$string = '1421600626570616650';
$hexnum = Math::BigInt->new("$string")->as_hex;
print "str $hexnum\n";

$hexnum = Math::BigInt->new("$num")->as_hex;
print "num $hexnum\n";
