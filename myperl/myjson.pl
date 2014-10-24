#!/home/y/bin/perl

use strict;
use warnings;
use JSON;


my %extacct = (
  email => 'abcd@gmail.com',
  type => 'imap'
);

my %resp = (
  yid => 'abcdefg',
  extacct => \%extacct,
);

my $json = JSON->new->allow_nonref;
 
my $json_text = $json->encode(\%resp);

print $json_text;
