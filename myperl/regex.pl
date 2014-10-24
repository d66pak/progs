#!/usr/bin/perl
# regex.pl


use warnings;
use strict;

my ($a, $b);

my $frmStr = "1203[1%]:1204[1%]:1208[3%]:1209[3%]:1210[3%]:1211[4%]:1212[10%]:1213[4%]:1214[3%]:1215[3%]:1216[3%]:1217[3%]:1218[3%]:1219[4%]:1220[4%]:1221[4%]:1222[4%]:1223[4%]:1224[4%]:1225[4%]:1226[4%]:1247[4%]:1249[4%]:1250[4%]:1251[4%]:1252[4%]:1253[4%]";

my $sum = 0;
while ($frmStr =~ m/(\d+)\[(\d{1,2})%\]/g) {
  print "<farm num=\"$1\" percent=\"$2\"/> \n";
  $sum += $2;
}
print "Sum: $sum \n";

open(my $fh, '<', "pop3header.txt") or die "Cannot open file: $!";

while (my $line = <$fh>) {

  if ($line =~ /^(Message-ID):\s+<(.*)>/i) {

    print "Message-Id: [$2]\n";
  }
}

close($fh);
