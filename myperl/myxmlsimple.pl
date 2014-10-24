#!/home/y/bin/perl

use strict;
use warnings;
use XML::Simple;
use Data::Dumper;

my $configfile = "reggateconfigmap.xml";

my $config = XMLin($configfile, Cache => ['memshare'], ContentKey => '-content', ForceArray => ['param']);

print Dumper($config);
