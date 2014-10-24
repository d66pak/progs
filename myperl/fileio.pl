#!/usr/bin/perl
# fileio.pl

use warnings;
use strict;

my $configfile = "/home/y/conf/ymail_reggate_tsn_xml_conf/registration.xml";
my $dtd_file = "/Users/dtelkar/Deepak/temp/registration.dtd";

print "configfile: $configfile \n";

my $dtd_f = $configfile;

if ($dtd_f =~ s/(xml)$/dtd/) {
  print "dtd_file:  $dtd_f \n";
}

$/ = undef;
open (DTDFH, $dtd_file) or die "Cannot open DTD file \n";

my $dtd_str = <DTDFH>;

print "DTD Str: \n";
print $dtd_str;
