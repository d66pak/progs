#!/home/y/bin/perl

use strict;
use warnings;

use YMail::Util;
use URI::Escape;

if (scalar @ARGV < 1) {

  print "Missing param to be decoded\n";
  die;
}

my $decodedParam = YMail::Util::decryptRocketmailData(CGI::unescape($ARGV[0]));

print "$decodedParam\n";

