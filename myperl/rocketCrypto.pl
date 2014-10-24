#!/home/y/bin/perl

use strict;
use warnings;
use Getopt::Long;
use YMail::Util;

my $strToEncrypt = undef;
my $strToDecrypt = undef;

sub usage() {

  print "Usage: $0 [-e string-to-encrypt][-d string-to-decrypt]\n";
  exit;
}

####### MAIN ###########

die usage() if (scalar (@ARGV) < 2);

GetOptions (
  'e:s' => \$strToEncrypt,
  'd:s' => \$strToDecrypt,
) or die usage();


if (defined $strToEncrypt && $strToEncrypt ne '') {

  my $encrypted = YMail::Util::encryptRocketmailData($strToEncrypt);
  print "Str to encrypt : $strToEncrypt\n";
  print "$encrypted\n";
} elsif (defined $strToDecrypt && $strToDecrypt ne '') {

  my $decrypted = YMail::Util::decryptRocketmailData($strToDecrypt);
  print "Str to decrypt : $strToDecrypt\n";
  print "$decrypted\n";
}

exit 0;


